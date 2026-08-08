import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../models/user_model.dart';

/// Database Helper class for managing SQLite database initialization and operations for user accounts.
class UserDatabaseHelper {
  static final UserDatabaseHelper _instance = UserDatabaseHelper._internal();
  factory UserDatabaseHelper() => _instance;
  UserDatabaseHelper._internal();

  static Database? _database;

  /// Returns the single active instance of the SQLite Database.
  /// Database is automatically initialized on demand / startup.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the SQLite database file and configures desktop FFI driver if running on Desktop.
  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows, Linux, or macOS desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'apna_pos_users_v2.db');
    } catch (_) {
      // Fallback for headless test environments where platform channels are not bound
      final dbFolder = await getDatabasesPath();
      path = join(dbFolder, 'apna_pos_users_v2.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Creates the "users" table with all required columns as per specifications.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phoneNumber TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        profileImage TEXT,
        createdAt TEXT NOT NULL,
        onboardingDetails TEXT
      )
    ''');
  }

  /// Inserts a new user entity into the SQLite "users" table.
  /// Returns the newly generated auto-incremented integer ID.
  Future<int> insertUserEntity(UserEntity user) async {
    final db = await database;
    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Retrieves user record matching the given email address.
  Future<UserEntity?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return UserEntity.fromMap(maps.first);
    }
    return null;
  }

  /// Retrieves user record matching the given phone number.
  Future<UserEntity?> getUserByPhone(String phoneNumber) async {
    final db = await database;
    final cleanPhone = phoneNumber.trim();
    final digitsOnly = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');

    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'phoneNumber = ? OR phoneNumber LIKE ?',
      whereArgs: [cleanPhone, '%$digitsOnly'],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return UserEntity.fromMap(maps.first);
    }
    return null;
  }

  /// Retrieves user record by either Email or Phone Number.
  Future<UserEntity?> getUserByEmailOrPhone(String identifier) async {
    final cleanId = identifier.trim().toLowerCase();
    if (cleanId.contains('@')) {
      return await getUserByEmail(cleanId);
    }

    final byPhone = await getUserByPhone(cleanId);
    if (byPhone != null) return byPhone;

    return await getUserByEmail(cleanId);
  }

  /// Retrieves user record by unique auto-incremented integer ID.
  Future<UserEntity?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return UserEntity.fromMap(maps.first);
    }
    return null;
  }

  /// Checks if an email address already exists in the database.
  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  /// Checks if a phone number already exists in the database.
  Future<bool> phoneExists(String phoneNumber) async {
    final user = await getUserByPhone(phoneNumber);
    return user != null;
  }

  /// Retrieves all user entities from the SQLite database.
  Future<List<UserEntity>> getAllUserEntities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', orderBy: 'id DESC');
    return maps.map((map) => UserEntity.fromMap(map)).toList();
  }

  /// Deletes a user record by ID.
  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compatibility helper method: inserts UserModel into SQLite database
  Future<int> insertUser(UserModel user) async {
    final entity = UserEntity(
      fullName: user.name,
      email: user.email,
      phoneNumber: user.phone ?? '',
      password: '1234',
      profileImage: user.profilePhotoPath,
      createdAt: DateTime.now().toIso8601String(),
    );
    return await insertUserEntity(entity);
  }

  /// Compatibility helper method: retrieves all users as UserModel
  Future<List<UserModel>> getAllUsers() async {
    final entities = await getAllUserEntities();
    return entities.map((e) => UserModel(
      id: e.id?.toString() ?? '',
      name: e.fullName,
      email: e.email,
      phone: e.phoneNumber,
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_001',
    )).toList();
  }
}
