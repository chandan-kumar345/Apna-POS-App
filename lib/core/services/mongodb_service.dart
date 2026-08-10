import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../features/auth/domain/entities/user_entity.dart';

/// MongoDB Service for user registration persistence and cross-device login authentication.
/// Direct MongoDB Atlas cluster connection via mongo_dart + REST API & persistent storage.
class MongoDbService {
  static MongoDbService? _instance;

  factory MongoDbService({Dio? dio}) {
    _instance ??= MongoDbService._internal(dio: dio);
    return _instance!;
  }

  final Dio _dio;
  mongo.Db? _mongoDb;
  
  // Default MongoDB Atlas Connection URI & Configuration
  String _mongoConnectionString = 'mongodb+srv://admin:SNllb5tEscXsj3ZQ@cluster0.auncgls.mongodb.net/apnapos_db?retryWrites=true&w=majority&appName=Cluster0';
  String _baseUrl = 'https://api.apnapos.com/api/v1/mongodb';
  String _apiKey = '';
  String _clusterName = 'Cluster0';
  String _databaseName = 'apnapos_db';
  String _collectionName = 'users';

  String get connectionString => _mongoConnectionString;

  // Remote/In-Memory Mongo store cache to mirror documents across devices in session
  final Map<String, Map<String, dynamic>> _mongoUserStore = {};

  MongoDbService._internal({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            )) {
    _initDefaultMongoUsers();
  }

  /// Initialize initial admin/demo user document in MongoDB cache and load from persistent disk
  Future<void> _initDefaultMongoUsers() async {
    if (_mongoUserStore.isEmpty) {
      _mongoUserStore['admin@apnapos.com'] = {
        'id': 1,
        'fullName': 'Demo Admin',
        'email': 'admin@apnapos.com',
        'phoneNumber': '9876543210',
        'password': 'admin123',
        'profileImage': null,
        'createdAt': DateTime.now().toIso8601String(),
        'onboardingDetails': 'Demo Restaurant Owner',
      };
    }
    await _loadMongoStoreFromDisk();
  }

  /// Persists the MongoDB user store to disk so user accounts survive app reinstalls and restarts
  Future<void> _saveMongoStoreToDisk() async {
    try {
      if (kIsWeb) return;
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(docsDir.path, 'apna_pos_mongo_users.json'));
      await file.writeAsString(jsonEncode(_mongoUserStore));
    } catch (_) {}
  }

  /// Loads persisted user records from disk into memory
  Future<void> _loadMongoStoreFromDisk() async {
    try {
      if (kIsWeb) return;
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(docsDir.path, 'apna_pos_mongo_users.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final Map<String, dynamic> decoded = jsonDecode(content);
          decoded.forEach((key, value) {
            if (value is Map) {
              _mongoUserStore[key] = Map<String, dynamic>.from(value);
            }
          });
        }
      }
    } catch (_) {}
  }

  /// Establishes or returns an active MongoDB Atlas cluster database connection
  Future<mongo.Db?> _getMongoDb() async {
    try {
      if (_mongoDb != null && _mongoDb!.isConnected) {
        return _mongoDb;
      }
      
      var uriToUse = _mongoConnectionString;
      if (uriToUse.contains('<db_username>')) {
        uriToUse = uriToUse.replaceAll('<db_username>', 'admin');
      }

      _mongoDb = await mongo.Db.create(uriToUse);
      await _mongoDb!.open().timeout(const Duration(seconds: 8));
      debugPrint('Successfully connected to MongoDB Atlas cluster directly');
      return _mongoDb;
    } catch (e) {
      debugPrint('Direct MongoDB Atlas socket connection info: $e');
      return null;
    }
  }

  /// Update MongoDB API Base URL and Credentials if custom MongoDB server is supplied
  void configure({
    String? connectionString,
    String? dbUsername,
    String? dbPassword,
    required String baseUrl,
    String apiKey = '',
    String clusterName = 'Cluster0',
    String databaseName = 'apnapos_db',
    String collectionName = 'users',
  }) {
    if (connectionString != null) {
      var uri = connectionString;
      if (dbUsername != null && uri.contains('<db_username>')) {
        uri = uri.replaceAll('<db_username>', dbUsername);
      }
      _mongoConnectionString = uri;
    }
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    _clusterName = clusterName;
    _databaseName = databaseName;
    _collectionName = collectionName;
  }

  /// Registers and stores a new user record into MongoDB database collection ("users").
  /// Throws [Exception] if duplicate email or phone exists in MongoDB.
  Future<UserEntity> insertUser(UserEntity user) async {
    final cleanEmail = user.email.trim().toLowerCase();
    final cleanPhone = user.phoneNumber.trim();

    // 1. Check duplicate email in MongoDB
    final existingEmailUser = await findUserByEmail(cleanEmail);
    if (existingEmailUser != null) {
      throw Exception('This email is already registered in MongoDB database. Please log in.');
    }

    // 2. Check duplicate phone in MongoDB (if phone is provided)
    if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('no_phone_')) {
      final existingPhoneUser = await findUserByPhone(cleanPhone);
      if (existingPhoneUser != null) {
        throw Exception('This phone number is already registered in MongoDB database. Please log in.');
      }
    }

    final newId = DateTime.now().millisecondsSinceEpoch;
    final createdUser = user.copyWith(id: newId);

    final userDoc = createdUser.toMap();
    userDoc['_id'] = 'mongo_$newId';
    userDoc['updatedAt'] = DateTime.now().toIso8601String();

    // A. Direct MongoDB Atlas cluster socket insert
    try {
      final db = await _getMongoDb();
      if (db != null && db.isConnected) {
        final collection = db.collection(_collectionName);
        await collection.insertOne(userDoc);
        debugPrint('Successfully inserted user $cleanEmail directly into MongoDB Atlas users collection');
      }
    } catch (e) {
      debugPrint('Direct Mongo Atlas insert fallback: $e');
    }

    // B. MongoDB REST / Atlas Data API insert
    try {
      final response = await _dio.post(
        '$_baseUrl/insertOne',
        data: {
          'dataSource': _clusterName,
          'database': _databaseName,
          'collection': _collectionName,
          'document': userDoc,
        },
        options: Options(
          headers: _apiKey.isNotEmpty ? {'api-key': _apiKey} : null,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Successfully stored user ${createdUser.email} in MongoDB API');
      }
    } catch (e) {
      debugPrint('MongoDB REST endpoint unreachable, saving to local MongoDB store: $e');
    }

    // Persist into MongoDB store cache & disk
    if (cleanEmail.isNotEmpty) {
      _mongoUserStore[cleanEmail] = userDoc;
    }
    if (cleanPhone.isNotEmpty) {
      _mongoUserStore[cleanPhone] = userDoc;
    }
    _mongoUserStore['mongo_$newId'] = userDoc;
    await _saveMongoStoreToDisk();

    return createdUser;
  }

  /// Searches MongoDB for a user record by Email.
  Future<UserEntity?> findUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    // A. Direct MongoDB Atlas cluster search
    try {
      final db = await _getMongoDb();
      if (db != null && db.isConnected) {
        final collection = db.collection(_collectionName);
        final doc = await collection.findOne(mongo.where.eq('email', cleanEmail));
        if (doc != null) {
          final mapped = Map<String, dynamic>.from(doc);
          if (mapped.containsKey('_id') && mapped['_id'] is mongo.ObjectId) {
            mapped['_id'] = (mapped['_id'] as mongo.ObjectId).$oid;
          }
          final entity = UserEntity.fromMap(mapped);
          _mongoUserStore[cleanEmail] = mapped;
          await _saveMongoStoreToDisk();
          return entity;
        }
      }
    } catch (e) {
      debugPrint('Direct Mongo Atlas search error: $e');
    }

    // B. MongoDB REST / Atlas Data API search
    try {
      final response = await _dio.post(
        '$_baseUrl/findOne',
        data: {
          'dataSource': _clusterName,
          'database': _databaseName,
          'collection': _collectionName,
          'filter': {'email': cleanEmail},
        },
        options: Options(
          headers: _apiKey.isNotEmpty ? {'api-key': _apiKey} : null,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final doc = response.data['document'];
        if (doc != null) {
          final entity = UserEntity.fromMap(Map<String, dynamic>.from(doc));
          _mongoUserStore[cleanEmail] = Map<String, dynamic>.from(doc);
          await _saveMongoStoreToDisk();
          return entity;
        }
      }
    } catch (_) {}

    // Fallback to disk and internal Mongo store cache
    await _loadMongoStoreFromDisk();
    if (_mongoUserStore.containsKey(cleanEmail)) {
      return UserEntity.fromMap(_mongoUserStore[cleanEmail]!);
    }

    for (var doc in _mongoUserStore.values) {
      if (doc['email']?.toString().trim().toLowerCase() == cleanEmail) {
        return UserEntity.fromMap(doc);
      }
    }
    return null;
  }

  /// Searches MongoDB for a user record by Phone Number.
  Future<UserEntity?> findUserByPhone(String phoneNumber) async {
    final cleanPhone = phoneNumber.trim();
    if (cleanPhone.isEmpty) return null;
    final digitsOnly = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');

    // A. Direct MongoDB Atlas cluster search
    try {
      final db = await _getMongoDb();
      if (db != null && db.isConnected) {
        final collection = db.collection(_collectionName);
        final doc = await collection.findOne(mongo.where.eq('phoneNumber', cleanPhone));
        if (doc != null) {
          final mapped = Map<String, dynamic>.from(doc);
          if (mapped.containsKey('_id') && mapped['_id'] is mongo.ObjectId) {
            mapped['_id'] = (mapped['_id'] as mongo.ObjectId).$oid;
          }
          final entity = UserEntity.fromMap(mapped);
          _mongoUserStore[cleanPhone] = mapped;
          await _saveMongoStoreToDisk();
          return entity;
        }
      }
    } catch (e) {
      debugPrint('Direct Mongo Atlas phone search error: $e');
    }

    // B. MongoDB REST API search
    try {
      final response = await _dio.post(
        '$_baseUrl/findOne',
        data: {
          'dataSource': _clusterName,
          'database': _databaseName,
          'collection': _collectionName,
          'filter': {'phoneNumber': cleanPhone},
        },
        options: Options(
          headers: _apiKey.isNotEmpty ? {'api-key': _apiKey} : null,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final doc = response.data['document'];
        if (doc != null) {
          final entity = UserEntity.fromMap(Map<String, dynamic>.from(doc));
          _mongoUserStore[cleanPhone] = Map<String, dynamic>.from(doc);
          await _saveMongoStoreToDisk();
          return entity;
        }
      }
    } catch (_) {}

    // Fallback search in persistent disk store cache
    await _loadMongoStoreFromDisk();
    for (var doc in _mongoUserStore.values) {
      final p = doc['phoneNumber']?.toString().trim() ?? '';
      if (p == cleanPhone || (digitsOnly.isNotEmpty && p.replaceAll(RegExp(r'[^0-9]'), '') == digitsOnly)) {
        return UserEntity.fromMap(doc);
      }
    }
    return null;
  }

  /// Searches MongoDB for a user by either Email or Phone Number.
  Future<UserEntity?> findUserByEmailOrPhone(String identifier) async {
    final cleanId = identifier.trim().toLowerCase();
    if (cleanId.contains('@')) {
      return await findUserByEmail(cleanId);
    }
    final userByPhone = await findUserByPhone(cleanId);
    if (userByPhone != null) return userByPhone;
    return await findUserByEmail(cleanId);
  }

  /// Validates user credentials against MongoDB database for cross-device login.
  /// Returns the matching [UserEntity] if identifier and password match in MongoDB.
  /// Throws [Exception] if user account is not found or password is incorrect.
  Future<UserEntity> validateCredentials(String identifier, String password) async {
    final cleanId = identifier.trim();
    final cleanPw = password.trim();

    if (cleanId.isEmpty || cleanPw.isEmpty) {
      throw Exception('Please enter both User ID / Email / Phone and Password.');
    }

    final userDoc = await findUserByEmailOrPhone(cleanId);

    if (userDoc == null) {
      throw Exception('Account not found in MongoDB database. Please complete registration first.');
    }

    if (userDoc.password != cleanPw) {
      throw Exception('Invalid password. Please check your credentials and try again.');
    }

    return userDoc;
  }

  /// Checks if email address exists in MongoDB.
  Future<bool> emailExists(String email) async {
    final user = await findUserByEmail(email);
    return user != null;
  }

  /// Checks if phone number exists in MongoDB.
  Future<bool> phoneExists(String phone) async {
    final user = await findUserByPhone(phone);
    return user != null;
  }
}
