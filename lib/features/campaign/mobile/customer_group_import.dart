import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import 'package:excel2003/excel2003.dart';
import 'package:xml/xml.dart';

/// Country code is required. Formatting punctuation and an Excel text prefix
/// are harmless; letters, extensions and scientific notation are rejected.
String? normalizeCustomerPhone(String input) {
  var value = input.trim().replaceFirst(RegExp(r"^'"), '');
  value = value.replaceAll(RegExp(r'[\s().-]'), '');
  if (value.startsWith('00')) value = '+${value.substring(2)}';
  if (RegExp(r'^[1-9]\d{10,14}$').hasMatch(value)) value = '+$value';
  if (value.startsWith('+91') && !RegExp(r'^\+91[6-9]\d{9}$').hasMatch(value)) {
    return null;
  }
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value) ? value : null;
}

class CustomerNumberCheck {
  final List<String> valid;
  final List<String> invalid;
  final int duplicates;
  final int entries;

  CustomerNumberCheck._(
    this.valid,
    this.invalid,
    this.duplicates,
    this.entries,
  );

  factory CustomerNumberCheck.parse(Iterable<String> values) {
    final unique = <String>{};
    final invalid = <String>[];
    var duplicates = 0;
    var entries = 0;
    for (final value in values) {
      if (value.trim().isEmpty) continue;
      entries++;
      final phone = normalizeCustomerPhone(value);
      if (phone == null) {
        invalid.add(value.trim());
      } else if (!unique.add(phone)) {
        duplicates++;
      }
    }
    return CustomerNumberCheck._(unique.toList(), invalid, duplicates, entries);
  }

  static List<String> manual(String value) => value
      .split(RegExp(r'[,;\r\n\t]+'))
      .where((entry) => entry.trim().isNotEmpty)
      .toList();
}

class CustomerImportTable {
  final String name;
  final List<String> columns;
  final List<List<String>> rows;
  final bool hasHeader;

  CustomerImportTable(this.name, List<List<String>> data)
    : hasHeader =
          data.isNotEmpty &&
          data.first.any(
            (v) => RegExp(
              r'^(name|customer name|mobile|mobile number|phone|phone number|contact|contact number|email)$',
              caseSensitive: false,
            ).hasMatch(v.trim()),
          ),
      columns = [],
      rows = [] {
    if (data.isEmpty) return;
    if (data.length > 50001) {
      throw const FormatException('Import up to 50,000 rows at a time.');
    }
    final width = data.fold<int>(
      0,
      (n, row) => row.length > n ? row.length : n,
    );
    if (width > 256) {
      throw const FormatException('Import a sheet with at most 256 columns.');
    }
    for (var i = 0; i < width; i++) {
      final title = hasHeader && i < data.first.length
          ? data.first[i].trim()
          : '';
      columns.add(title.isEmpty ? 'Column ${i + 1}' : title);
    }
    rows.addAll(hasHeader ? data.skip(1) : data);
  }

  int get suggestedColumn {
    final named = columns.indexWhere(
      (name) => RegExp(
        r'phone|mobile|contact|number',
        caseSensitive: false,
      ).hasMatch(name),
    );
    if (named >= 0) return named;
    var best = 0, score = -1;
    for (var column = 0; column < columns.length; column++) {
      final count = values(
        column,
      ).where((v) => normalizeCustomerPhone(v) != null).length;
      if (count > score) {
        best = column;
        score = count;
      }
    }
    return best;
  }

  Iterable<String> values(int column) =>
      rows.map((row) => column < row.length ? row[column] : '');
}

/// Runs via compute on native platforms so file decoding does not block input.
List<CustomerImportTable> decodeCustomerImport(Map<String, Object> input) {
  final bytes = input['bytes'] as Uint8List;
  final extension = input['extension'] as String;
  if (extension == 'csv') {
    final text = utf8.decode(bytes).replaceFirst('\uFEFF', '');
    final data = Csv(dynamicTyping: false).decode(text);
    return [
      CustomerImportTable(
        'CSV',
        data.map((r) => r.map((v) => v?.toString() ?? '').toList()).toList(),
      ),
    ];
  }
  if (extension == 'xls') {
    final reader = XlsReader.fromBytes(bytes)..open();
    return List.generate(reader.sheetCount, (index) {
      final sheet = reader.sheet(index);
      if (sheet.lastRow - sheet.firstRow > 50001 || sheet.lastCol > 256) {
        throw const FormatException(
          'Import up to 50,000 rows and 256 columns at a time.',
        );
      }
      final rows = <List<String>>[];
      for (var row = sheet.firstRow; row < sheet.lastRow; row++) {
        rows.add(
          List.generate(
            sheet.lastCol,
            (column) => _cellText(sheet.cell(row, column)),
          ),
        );
      }
      return CustomerImportTable(
        reader.sheetNames[index],
        rows.where((row) => row.any((v) => v.trim().isNotEmpty)).toList(),
      );
    });
  }
  return _decodeXlsx(bytes);
}

String _cellText(Object? value) =>
    value is double && value.isFinite && value == value.truncateToDouble()
    ? value.toInt().toString()
    : value?.toString() ?? '';

Iterable<XmlElement> _elements(XmlNode node, String name) =>
    node.descendants.whereType<XmlElement>().where((e) => e.name.local == name);

List<CustomerImportTable> _decodeXlsx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  XmlDocument document(String path) {
    final file = archive.findFile(path);
    if (file == null || file.size > 40 * 1024 * 1024) {
      throw const FormatException('Unreadable or oversized worksheet.');
    }
    return XmlDocument.parse(utf8.decode(file.content));
  }

  final stringsFile = archive.findFile('xl/sharedStrings.xml');
  final strings = stringsFile == null
      ? <String>[]
      : _elements(document('xl/sharedStrings.xml'), 'si')
            .map((si) => _elements(si, 't').map((t) => t.innerText).join())
            .toList();
  final relations = {
    for (final r in _elements(
      document('xl/_rels/workbook.xml.rels'),
      'Relationship',
    ))
      r.getAttribute('Id'): r.getAttribute('Target'),
  };
  final tables = <CustomerImportTable>[];
  for (final sheet in _elements(document('xl/workbook.xml'), 'sheet')) {
    final id = sheet.attributes
        .where((a) => a.name.local == 'id')
        .firstOrNull
        ?.value;
    var target = relations[id];
    if (target == null) continue;
    target = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final rows = <List<String>>[];
    for (final row in _elements(document(target), 'row')) {
      if (rows.length >= 50000) {
        throw const FormatException('Import up to 50,000 rows at a time.');
      }
      final values = <String>[];
      for (final cell in _elements(row, 'c')) {
        final ref = cell.getAttribute('r') ?? '';
        var column = 0;
        for (final letter
            in RegExp(r'^[A-Z]+').stringMatch(ref)?.codeUnits ?? <int>[]) {
          column = column * 26 + letter - 64;
        }
        if (column == 0) column = values.length + 1;
        if (column > 256) {
          throw const FormatException(
            'Import a sheet with at most 256 columns.',
          );
        }
        while (values.length < column) {
          values.add('');
        }
        final raw = _elements(cell, 'v').firstOrNull?.innerText ?? '';
        final type = cell.getAttribute('t');
        values[column - 1] = switch (type) {
          's' => strings[int.parse(raw)],
          'inlineStr' => _elements(cell, 't').map((t) => t.innerText).join(),
          'b' || 'e' => raw.isEmpty ? '' : 'Invalid cell: $raw',
          'str' => raw,
          _ => _cellText(num.tryParse(raw) ?? raw),
        };
      }
      if (values.any((v) => v.trim().isNotEmpty)) rows.add(values);
    }
    if (rows.isNotEmpty) {
      tables.add(
        CustomerImportTable(sheet.getAttribute('name') ?? 'Sheet', rows),
      );
    }
  }
  return tables;
}
