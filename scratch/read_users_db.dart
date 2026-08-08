import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_windows/path_provider_windows.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final pathProvider = PathProviderWindows();
  final docsPath = await pathProvider.getApplicationDocumentsPath();
  final dbPath = p.join(docsPath!, 'apna_pos_users_v2.db');

  print('DATABASE_PATH: $dbPath');

  final db = await openDatabase(dbPath);
  final List<Map<String, dynamic>> users = await db.query('users');

  print('TOTAL_USERS_COUNT: ${users.length}');
  print('--- USER RECORDS ---');
  for (var user in users) {
    print(user);
  }
}
