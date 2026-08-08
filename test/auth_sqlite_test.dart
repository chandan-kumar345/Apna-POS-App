import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apna_pos/features/auth/domain/entities/user_entity.dart';
import 'package:apna_pos/features/auth/data/repositories/sqlite_auth_repository.dart';
import 'package:apna_pos/core/database/user_database_helper.dart';
import 'package:apna_pos/core/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup sqflite FFI for running tests in desktop VM environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SQLite Auth & Session Repository Tests', () {
    late SqliteAuthRepository authRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      authRepository = SqliteAuthRepository();
      final db = await UserDatabaseHelper().database;
      await db.delete('users');
    });

    test('1. SQLite users table creation and user registration', () async {
      const user = UserEntity(
        fullName: 'Test Restaurant Owner',
        email: 'owner@restaurant.com',
        phoneNumber: '9876543210',
        password: 'SecurePassword123',
        profileImage: 'assets/images/profile.png',
        createdAt: '2026-08-08T18:00:00Z',
        onboardingDetails: 'Fine Dining - 20 Tables',
      );

      final registeredUser = await authRepository.registerUser(user);

      expect(registeredUser.id, isNotNull);
      expect(registeredUser.fullName, equals('Test Restaurant Owner'));
      expect(registeredUser.email, equals('owner@restaurant.com'));
      expect(registeredUser.phoneNumber, equals('9876543210'));
    });

    test('2. Prevent duplicate email registration', () async {
      const user1 = UserEntity(
        fullName: 'Owner One',
        email: 'duplicate@restaurant.com',
        phoneNumber: '9111111111',
        password: 'Pass1',
        createdAt: '2026-08-08',
      );

      await authRepository.registerUser(user1);

      const user2 = UserEntity(
        fullName: 'Owner Two',
        email: 'duplicate@restaurant.com',
        phoneNumber: '9222222222',
        password: 'Pass2',
        createdAt: '2026-08-08',
      );

      expect(
        () async => await authRepository.registerUser(user2),
        throwsA(isA<Exception>()),
      );
    });

    test('3. Prevent duplicate phone number registration', () async {
      const user1 = UserEntity(
        fullName: 'Owner Phone One',
        email: 'unique1@restaurant.com',
        phoneNumber: '9998887770',
        password: 'Pass1',
        createdAt: '2026-08-08',
      );

      await authRepository.registerUser(user1);

      const user2 = UserEntity(
        fullName: 'Owner Phone Two',
        email: 'unique2@restaurant.com',
        phoneNumber: '9998887770',
        password: 'Pass2',
        createdAt: '2026-08-08',
      );

      expect(
        () async => await authRepository.registerUser(user2),
        throwsA(isA<Exception>()),
      );
    });

    test('4. Login using Email + Password', () async {
      const user = UserEntity(
        fullName: 'Email Login User',
        email: 'login_email@apnapos.com',
        phoneNumber: '9888777666',
        password: 'PasswordEmail123',
        createdAt: '2026-08-08',
      );

      await authRepository.registerUser(user);

      final loggedInUser = await authRepository.login('login_email@apnapos.com', 'PasswordEmail123');

      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.email, equals('login_email@apnapos.com'));

      final isSessionActive = await SessionManager().isLoggedIn();
      expect(isSessionActive, isTrue);
    });

    test('5. Login using Phone Number + Password', () async {
      const user = UserEntity(
        fullName: 'Phone Login User',
        email: 'login_phone@apnapos.com',
        phoneNumber: '9777666555',
        password: 'PasswordPhone123',
        createdAt: '2026-08-08',
      );

      await authRepository.registerUser(user);

      final loggedInUser = await authRepository.login('9777666555', 'PasswordPhone123');

      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.phoneNumber, equals('9777666555'));

      final isSessionActive = await SessionManager().isLoggedIn();
      expect(isSessionActive, isTrue);
    });

    test('6. Reject invalid login credentials', () async {
      expect(
        () async => await authRepository.login('nonexistent@apnapos.com', 'WrongPass'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
