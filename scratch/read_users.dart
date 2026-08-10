import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Search possible database paths
  final docsPath = Platform.environment['USERPROFILE'] != null
      ? p.join(Platform.environment['USERPROFILE']!, 'Documents', 'apna_pos_users_v2.db')
      : '';
  
  final altPath = p.join(Directory.current.path, 'apna_pos_users_v2.db');

  String targetPath = docsPath;
  if (!File(docsPath).existsSync()) {
    if (File(altPath).existsSync()) {
      targetPath = altPath;
    } else {
      print('Database file not found at $docsPath or $altPath');
      // Let's check for any .db files in Documents
      final docsDir = Directory(p.join(Platform.environment['USERPROFILE']!, 'Documents'));
      if (docsDir.existsSync()) {
        final dbFiles = docsDir.listSync().where((f) => f.path.endsWith('.db')).toList();
        print('Found DB files in Documents: ${dbFiles.map((f) => f.path).toList()}');
        if (dbFiles.isNotEmpty) {
          targetPath = dbFiles.first.path;
        }
      }
    }
  }

  print('Opening SQLite database at: $targetPath\n');
  if (!File(targetPath).existsSync()) {
    print('No database file found yet. You can run tests or register a user in the app.');
    return;
  }

  final db = await openDatabase(targetPath);
  try {
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    print('Tables in database: ${tables.map((t) => t['name']).toList()}\n');

    for (var tableMap in tables) {
      final tableName = tableMap['name'] as String;
      if (tableName == 'sqlite_sequence') continue;
      print('=== TABLE: $tableName ===');
      final rows = await db.query(tableName);
      if (rows.isEmpty) {
        print('(Table is empty)');
      } else {
        for (var i = 0; i < rows.length; i++) {
          print('Row #${i + 1}: ${rows[i]}');
        }
      }
      print('');
    }
  } catch (e) {
    print('Error reading database: $e');
  } finally {
    await db.close();
  }
}
