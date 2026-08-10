import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Read and Print SQLite Saved User Credentials', () async {
    final candidatePaths = <String>[];

    try {
      final docs = await getApplicationDocumentsDirectory();
      candidatePaths.add(p.join(docs.path, 'apna_pos_users_v2.db'));
      candidatePaths.add(p.join(docs.path, 'apna_pos_users.db'));
    } catch (_) {}

    try {
      final dbFolder = await getDatabasesPath();
      candidatePaths.add(p.join(dbFolder, 'apna_pos_users_v2.db'));
      candidatePaths.add(p.join(dbFolder, 'apna_pos_users.db'));
    } catch (_) {}

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      candidatePaths.add(p.join(userProfile, 'Documents', 'apna_pos_users_v2.db'));
      candidatePaths.add(p.join(userProfile, 'Documents', 'apna_pos_users.db'));
    }

    print('\n================================================================');
    print('  CHECKING SQLITE DATABASE FILES IN ENVIRONMENT:');
    print('================================================================');

    bool foundAnyDb = false;

    for (var path in candidatePaths.toSet()) {
      final file = File(path);
      print('Checking path: $path => ${file.existsSync() ? "EXISTS ✅" : "NOT FOUND ❌"}');
      
      if (file.existsSync()) {
        foundAnyDb = true;
        print('\n----------------------------------------------------------------');
        print(' OPENING SQLITE DATABASE FILE:');
        print(' $path');
        print('----------------------------------------------------------------');
        
        final db = await openDatabase(path);
        try {
          final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
          print('Tables in DB: ${tables.map((t) => t['name']).toList()}');

          for (var tMap in tables) {
            final tName = tMap['name'] as String;
            if (tName == 'sqlite_sequence') continue;
            
            final rows = await db.query(tName);
            print('\n=== TABLE: $tName (${rows.length} records) ===');
            for (var i = 0; i < rows.length; i++) {
              print('Record #${i + 1}:');
              rows[i].forEach((key, value) {
                print('   • $key: $value');
              });
              print('');
            }
          }
        } catch (e) {
          print('Error querying DB: $e');
        } finally {
          await db.close();
        }
      }
    }

    if (!foundAnyDb) {
      print('\nNo SQLite database files found on disk yet.');
    }
    print('================================================================\n');
  });
}
