import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';

class UserDatabaseHelper {
  static final UserDatabaseHelper _instance = UserDatabaseHelper._internal();
  factory UserDatabaseHelper() => _instance;
  UserDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows, Linux, or macOS desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'apna_pos_users.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        role TEXT,
        pin TEXT,
        restaurantId TEXT,
        phone TEXT,
        jobTitle TEXT,
        companyName TEXT,
        website TEXT,
        referralCode TEXT,
        profilePhotoPath TEXT,
        communicationPreferences TEXT
      )
    ''');
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    Map<String, dynamic> row = user.toJson();
    // Convert Map to JSON String for SQLite storage
    if (row['communicationPreferences'] != null) {
      row['communicationPreferences'] = jsonEncode(row['communicationPreferences']);
    }
    
    return await db.insert(
      'users',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');

    return List.generate(maps.length, (i) {
      Map<String, dynamic> row = Map<String, dynamic>.from(maps[i]);
      if (row['communicationPreferences'] != null) {
        if (row['communicationPreferences'] is String) {
          row['communicationPreferences'] = jsonDecode(row['communicationPreferences']);
        }
      }
      return UserModel.fromJson(row);
    });
  }
  
  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      Map<String, dynamic> row = Map<String, dynamic>.from(maps.first);
      if (row['communicationPreferences'] != null && row['communicationPreferences'] is String) {
        row['communicationPreferences'] = jsonDecode(row['communicationPreferences']);
      }
      return UserModel.fromJson(row);
    }
    return null;
  }
}
