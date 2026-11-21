import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

Uint8List customerXlsxFixture() {
  final files = <String, String>{
    'xl/workbook.xml':
        '<x:workbook xmlns:x="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><x:sheets><x:sheet name="Customers" sheetId="1" r:id="rId1"/><x:sheet name="More" sheetId="2" r:id="rId2"/></x:sheets></x:workbook>',
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Target="/xl/worksheets/sheet2.xml"/></Relationships>',
    'xl/sharedStrings.xml':
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Name</t></si><si><r><t>Mobile </t></r><r><t>Number</t></r></si><si><t>+919876500002</t></si></sst>',
    'xl/worksheets/sheet1.xml':
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
        '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row>'
        '<row r="2"><c r="A2" t="inlineStr"><is><t>Sample customer</t></is></c><c r="C2"><v>9.19876500001E11</v></c></row>'
        '<row r="3"><c r="C3" t="s"><v>2</v></c></row></sheetData></worksheet>',
    'xl/worksheets/sheet2.xml':
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row><c r="A1" t="inlineStr"><is><t>Phone</t></is></c></row><row><c r="A2"><v>919876500003</v></c></row></sheetData></worksheet>',
  };
  final archive = Archive();
  for (final file in files.entries) {
    final bytes = utf8.encode(file.value);
    archive.addFile(ArchiveFile(file.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// A small OLE2 compound file with a BIFF8 workbook, a header and two numbers.
Uint8List customerXlsFixture() {
  Uint8List record(int type, Uint8List content) {
    final bytes = Uint8List(content.length + 4);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, type, Endian.little);
    data.setUint16(2, content.length, Endian.little);
    bytes.setRange(4, bytes.length, content);
    return bytes;
  }

  Uint8List bof(int type) {
    final bytes = Uint8List(16), data = ByteData(16);
    data.setUint16(0, 0x0600, Endian.little);
    data.setUint16(2, type, Endian.little);
    bytes.setAll(0, data.buffer.asUint8List());
    return record(0x0809, bytes);
  }

  final bounds = Uint8List(14);
  ByteData.sublistView(bounds).setUint32(0, 42, Endian.little);
  bounds[6] = 6;
  bounds.setAll(8, ascii.encode('Phones'));
  final workbook = BytesBuilder()
    ..add(bof(5))
    ..add(record(0x0085, bounds))
    ..add(record(0x000A, Uint8List(0)))
    ..add(bof(0x10));
  final dimensions = Uint8List(14), dimensionsData = ByteData(14);
  dimensionsData.setUint32(4, 3, Endian.little);
  dimensionsData.setUint16(10, 1, Endian.little);
  dimensions.setAll(0, dimensionsData.buffer.asUint8List());
  workbook.add(record(0x0200, dimensions));
  final label = Uint8List(14);
  ByteData.sublistView(label).setUint16(6, 5, Endian.little);
  label.setAll(9, ascii.encode('Phone'));
  workbook.add(record(0x0204, label));
  for (var row = 1; row <= 2; row++) {
    final number = Uint8List(14), data = ByteData.sublistView(number);
    data.setUint16(0, row, Endian.little);
    data.setFloat64(6, 919876500000 + row.toDouble(), Endian.little);
    workbook.add(record(0x0203, number));
  }
  workbook.add(record(0x000A, Uint8List(0)));
  final bytes = Uint8List(5632), data = ByteData.sublistView(bytes);
  bytes.setAll(0, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]);
  for (final field in {24: 0x003E, 26: 3, 28: 0xFFFE, 30: 9, 32: 6}.entries) {
    data.setUint16(field.key, field.value, Endian.little);
  }
  for (final field in {
    44: 1,
    48: 1,
    56: 4096,
    60: 0xFFFFFFFE,
    68: 0xFFFFFFFE,
  }.entries) {
    data.setUint32(field.key, field.value, Endian.little);
  }
  for (var i = 0; i < 109; i++) {
    data.setUint32(76 + i * 4, i == 0 ? 0 : 0xFFFFFFFF, Endian.little);
  }
  for (var i = 0; i < 128; i++) {
    final value = i == 0
        ? 0xFFFFFFFD
        : i == 1 || i == 9
        ? 0xFFFFFFFE
        : i >= 2 && i < 9
        ? i + 1
        : 0xFFFFFFFF;
    data.setUint32(512 + i * 4, value, Endian.little);
  }
  void entry(int offset, String name, int type, int sector, int size) {
    for (var i = 0; i < name.length; i++) {
      data.setUint16(offset + i * 2, name.codeUnitAt(i), Endian.little);
    }
    data.setUint16(offset + 64, (name.length + 1) * 2, Endian.little);
    bytes[offset + 66] = type;
    bytes[offset + 67] = 1;
    for (final field in [68, 72, 76]) {
      data.setUint32(offset + field, 0xFFFFFFFF, Endian.little);
    }
    data.setUint32(offset + 116, sector, Endian.little);
    data.setUint32(offset + 120, size, Endian.little);
  }

  entry(1024, 'Root Entry', 5, 0xFFFFFFFE, 0);
  data.setUint32(1024 + 76, 1, Endian.little);
  entry(1152, 'Workbook', 2, 2, 4096);
  bytes.setAll(1536, workbook.toBytes());
  return bytes;
}
