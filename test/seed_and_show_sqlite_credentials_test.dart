import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apna_pos/features/auth/domain/entities/user_entity.dart';
import 'package:apna_pos/features/auth/data/repositories/sqlite_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Insert Demo Registered User & Display SQLite Records', () async {
    SharedPreferences.setMockInitialValues({});
    final authRepo = SqliteAuthRepository();

    // Insert user into SQLite DB if empty
    final dbFolder = await getDatabasesPath();
    final dbPath = p.join(dbFolder, 'apna_pos_users_v2.db');
    final db = await openDatabase(dbPath);

    final existingUsers = await db.query('users');
    if (existingUsers.isEmpty) {
      const demoUser = UserEntity(
        fullName: 'Chandan Kumar',
        email: 'chandan@apnapos.com',
        phoneNumber: '9876543210',
        password: 'Password@123',
        profileImage: 'assets/images/user_profile.png',
        createdAt: '2026-08-10T13:57:00Z',
        onboardingDetails: 'Apna POS Diner - Restaurant Owner',
      );
      await authRepo.registerUser(demoUser);
    }

    final rows = await db.query('users');

    print('\n================================================================');
    print('  SQLITE DATABASE FILE PATH:');
    print('  $dbPath');
    print('================================================================\n');

    print('----------------------------------------------------------------');
    print('  SAVED USER CREDENTIALS IN SQLITE DATABASE ("users" table)');
    print('----------------------------------------------------------------');

    for (var i = 0; i < rows.length; i++) {
      final u = rows[i];
      print('RECORD #${i + 1}:');
      print('  • id:                 ${u['id']}');
      print('  • fullName:           ${u['fullName']}');
      print('  • email:              ${u['email']}');
      print('  • phoneNumber:        ${u['phoneNumber']}');
      print('  • password:           ${u['password']}');
      print('  • profileImage:       ${u['profileImage']}');
      print('  • createdAt:          ${u['createdAt']}');
      print('  • onboardingDetails:  ${u['onboardingDetails']}');
      print('----------------------------------------------------------------');
    }

    await db.close();
  });
}
