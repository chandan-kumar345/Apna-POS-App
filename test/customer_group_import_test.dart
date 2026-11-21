import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/campaign/mobile/customer_group_import.dart';
import 'support/customer_import_fixtures.dart';

void main() {
  test(
    'normalizes international formats and deduplicates manual and file entries',
    () {
      final result = CustomerNumberCheck.parse([
        ...CustomerNumberCheck.manual(
          '+91 98765 00001, 00919876500001; +1 (415) 555-2671\nno phone\n+912345\n9876500001',
        ),
        "'919876500001",
        '919876500002',
        '',
        '9.198765E11',
        '+919876500001 ext 2',
      ]);
      expect(result.valid, ['+919876500001', '+14155552671', '+919876500002']);
      expect(result.duplicates, 2);
      expect(result.invalid.length, 5);
      expect(result.entries, 10);
      expect(
        result.entries,
        result.valid.length + result.duplicates + result.invalid.length,
      );
    },
  );
  test(
    'CSV preserves country-code text, quoted fields, BOM and blank values',
    () {
      final tables = decodeCustomerImport({
        'bytes': Uint8List.fromList(
          utf8.encode(
            '\uFEFFName,Mobile Number,Other\r\n"Sample, customer",+919876500001,123\r\nAnother,919876500002,456\r\nEmpty,,789\r\n',
          ),
        ),
        'extension': 'csv',
      });
      expect(tables.single.rows.length, 3);
      expect(tables.single.suggestedColumn, 1);
      expect(
        CustomerNumberCheck.parse(tables.single.values(1)).valid.length,
        2,
      );
    },
  );
  test('headerless contact rows are retained', () {
    final table = CustomerImportTable('Contacts', [
      ['Jane', '+919876500001'],
      ['Joe', '+919876500002'],
    ]);
    expect(table.hasHeader, isFalse);
    expect(table.rows.length, 2);
    expect(table.suggestedColumn, 1);
  });
  test(
    'XLSX decodes shared and inline strings, sparse cells, numeric phones and multiple sheets',
    () {
      final tables = decodeCustomerImport({
        'bytes': customerXlsxFixture(),
        'extension': 'xlsx',
      });
      expect(tables.map((t) => t.name), ['Customers', 'More']);
      expect(tables.first.suggestedColumn, 2);
      expect(tables.first.columns, ['Name', 'Column 2', 'Mobile Number']);
      expect(CustomerNumberCheck.parse(tables.first.values(2)).valid, [
        '+919876500001',
        '+919876500002',
      ]);
      expect(CustomerNumberCheck.parse(tables.last.values(0)).valid, [
        '+919876500003',
      ]);
    },
  );
  test('legacy binary XLS decodes real BIFF8 numeric cells', () {
    final table = decodeCustomerImport({
      'bytes': customerXlsFixture(),
      'extension': 'xls',
    }).single;
    expect(table.name, 'Phones');
    expect(table.columns, ['Phone']);
    expect(CustomerNumberCheck.parse(table.values(0)).valid, [
      '+919876500001',
      '+919876500002',
    ]);
  });
  test(
    'corrupt workbooks fail instead of silently importing fabricated data',
    () {
      expect(
        () => decodeCustomerImport({
          'bytes': Uint8List.fromList([1, 2, 3]),
          'extension': 'xlsx',
        }),
        throwsA(anything),
      );
    },
  );
}
