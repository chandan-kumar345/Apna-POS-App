import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apna_pos/features/auth/domain/entities/user_entity.dart';
import 'package:apna_pos/features/auth/data/repositories/mongo_auth_repository.dart';
import 'package:apna_pos/core/services/mongodb_service.dart';
import 'package:apna_pos/core/database/user_database_helper.dart';
import 'package:apna_pos/core/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup sqflite FFI for desktop test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MongoDB User Registration & Cross-Device Auth Tests', () {
    late MongoAuthRepository mongoAuthRepo;
    late MongoDbService mongoService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mongoService = MongoDbService();
      mongoAuthRepo = MongoAuthRepository(mongoService: mongoService);
      
      final db = await UserDatabaseHelper().database;
      await db.delete('users');
    });

    test('1. Register user and store in MongoDB database', () async {
      const user = UserEntity(
        fullName: 'MongoDB Owner',
        email: 'mongo_owner@apnapos.com',
        phoneNumber: '9123456789',
        password: 'MongoSecretPassword123',
        createdAt: '2026-08-10T12:00:00Z',
        onboardingDetails: 'Cross-Device Multi Outlet Store',
      );

      final registered = await mongoAuthRepo.registerUser(user);

      expect(registered.fullName, equals('MongoDB Owner'));
      expect(registered.email, equals('mongo_owner@apnapos.com'));

      final storedInMongo = await mongoService.findUserByEmail('mongo_owner@apnapos.com');
      expect(storedInMongo, isNotNull);
      expect(storedInMongo!.fullName, equals('MongoDB Owner'));
    });

    test('2. Cross-Device Login with Email & Password validated against MongoDB', () async {
      const user = UserEntity(
        fullName: 'Device 1 Owner',
        email: 'device1_user@apnapos.com',
        phoneNumber: '9888111222',
        password: 'PassFromDevice1',
        createdAt: '2026-08-10',
      );

      // Device 1 registers user in MongoDB
      await mongoAuthRepo.registerUser(user);

      // Device 2 (simulated fresh session) logs in using registered Email & Password
      await mongoAuthRepo.clearSession();

      final loggedInUser = await mongoAuthRepo.login('device1_user@apnapos.com', 'PassFromDevice1');

      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.email, equals('device1_user@apnapos.com'));
      expect(await SessionManager().isLoggedIn(), isTrue);
    });

    test('3. Cross-Device Login with Phone Number & Password validated against MongoDB', () async {
      const user = UserEntity(
        fullName: 'Phone Device User',
        email: 'phone_user@apnapos.com',
        phoneNumber: '9991112223',
        password: 'PhonePassword123',
        createdAt: '2026-08-10',
      );

      await mongoAuthRepo.registerUser(user);
      await mongoAuthRepo.clearSession();

      final loggedInUser = await mongoAuthRepo.login('9991112223', 'PhonePassword123');

      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.phoneNumber, equals('9991112223'));
    });

    test('4. Reject invalid password during login validation against MongoDB', () async {
      const user = UserEntity(
        fullName: 'Secure User',
        email: 'secure_user@apnapos.com',
        phoneNumber: '9777555333',
        password: 'CorrectPassword123',
        createdAt: '2026-08-10',
      );

      await mongoAuthRepo.registerUser(user);

      expect(
        () async => await mongoAuthRepo.login('secure_user@apnapos.com', 'WrongPassword'),
        throwsA(isA<Exception>()),
      );
    });

    test('5. Prevent duplicate email registration in MongoDB', () async {
      const user1 = UserEntity(
        fullName: 'First Register',
        email: 'duplicate_check@apnapos.com',
        phoneNumber: '9555444333',
        password: 'Pass1',
        createdAt: '2026-08-10',
      );

      await mongoAuthRepo.registerUser(user1);

      const user2 = UserEntity(
        fullName: 'Second Register',
        email: 'duplicate_check@apnapos.com',
        phoneNumber: '9555444334',
        password: 'Pass2',
        createdAt: '2026-08-10',
      );

      expect(
        () async => await mongoAuthRepo.registerUser(user2),
        throwsA(isA<Exception>()),
      );
    });
  });
}
