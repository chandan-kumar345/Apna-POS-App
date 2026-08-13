import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../../../core/database/user_database_helper.dart';
import '../../../../core/services/mongodb_service.dart';
import '../../../../core/services/session_manager.dart';

/// Implementation of [IAuthRepository] using MongoDB database via [MongoDbService]
/// for cross-device authentication with local SQLite sync via [UserDatabaseHelper].
class MongoAuthRepository implements IAuthRepository {
  final MongoDbService _mongoService;
  final UserDatabaseHelper _dbHelper;
  final SessionManager _sessionManager;

  MongoAuthRepository({
    MongoDbService? mongoService,
    UserDatabaseHelper? dbHelper,
    SessionManager? sessionManager,
  })  : _mongoService = mongoService ?? MongoDbService(),
        _dbHelper = dbHelper ?? UserDatabaseHelper(),
        _sessionManager = sessionManager ?? SessionManager();

  @override
  Future<UserEntity> registerUser(UserEntity user) async {
    // 1. Field Validation
    if (user.fullName.trim().isEmpty) {
      throw Exception('Full Name is required');
    }
    if (user.email.trim().isEmpty && user.phoneNumber.trim().isEmpty) {
      throw Exception('Email address or Phone number is required');
    }
    if (user.email.trim().isNotEmpty && !user.email.contains('@')) {
      throw Exception('A valid email address is required');
    }
    if (user.password.trim().isEmpty) {
      throw Exception('Password is required');
    }

    // 2. Register & Store user in MongoDB database
    final createdUser = await _mongoService.insertUser(user);

    // 3. Sync to local SQLite database for offline access
    try {
      final insertedId = await _dbHelper.insertUserEntity(createdUser);
      final finalUser = createdUser.copyWith(id: insertedId);
      if (finalUser.id != null) {
        await saveSession(finalUser.id!);
      }
      return finalUser;
    } catch (_) {
      if (createdUser.id != null) {
        await saveSession(createdUser.id!);
      }
      return createdUser;
    }
  }

  @override
  Future<UserEntity?> login(String identifier, String password) async {
    final cleanId = identifier.trim();
    final cleanPw = password.trim();

    if (cleanId.isEmpty || cleanPw.isEmpty) {
      throw Exception('Please enter both identifier and password');
    }

    try {
      // 1. Validate credentials against MongoDB database for cross-device support
      final userFromMongo = await _mongoService.validateCredentials(cleanId, cleanPw);

      // 2. Sync user document to local SQLite database if missing
      try {
        final existingLocalUser = await _dbHelper.getUserByEmailOrPhone(cleanId);
        if (existingLocalUser == null) {
          final insertedId = await _dbHelper.insertUserEntity(userFromMongo);
          final syncedUser = userFromMongo.copyWith(id: insertedId);
          await saveSession(syncedUser.id!);
          return syncedUser;
        } else if (userFromMongo.id != null) {
          await saveSession(userFromMongo.id!);
        } else if (existingLocalUser.id != null) {
          await saveSession(existingLocalUser.id!);
        }
      } catch (_) {
        if (userFromMongo.id != null) {
          await saveSession(userFromMongo.id!);
        }
      }

      return userFromMongo;
    } catch (mongoError) {
      // Offline / Local SQLite fallback authentication
      final localUser = await _dbHelper.getUserByEmailOrPhone(cleanId);
      if (localUser != null && localUser.password == cleanPw) {
        if (localUser.id != null) {
          await saveSession(localUser.id!);
        }
        return localUser;
      }
      rethrow;
    }
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    final mongoExists = await _mongoService.emailExists(email);
    if (mongoExists) return true;
    return await _dbHelper.emailExists(email);
  }

  @override
  Future<bool> checkPhoneExists(String phoneNumber) async {
    final mongoExists = await _mongoService.phoneExists(phoneNumber);
    if (mongoExists) return true;
    return await _dbHelper.phoneExists(phoneNumber);
  }

  @override
  Future<UserEntity?> getUserById(int id) async {
    final localUser = await _dbHelper.getUserById(id);
    if (localUser != null) return localUser;
    return null;
  }

  @override
  Future<UserEntity?> getUserByEmailOrPhone(String identifier) async {
    final mongoUser = await _mongoService.findUserByEmailOrPhone(identifier);
    if (mongoUser != null) return mongoUser;
    return await _dbHelper.getUserByEmailOrPhone(identifier);
  }

  @override
  Future<bool> isSessionLoggedIn() async {
    return await _sessionManager.isLoggedIn();
  }

  @override
  Future<int?> getLoggedInUserId() async {
    return await _sessionManager.getLoggedInUserId();
  }

  @override
  Future<void> saveSession(int userId) async {
    await _sessionManager.saveSession(userId);
  }

  @override
  Future<void> clearSession() async {
    await _sessionManager.clearSession();
  }

  @override
  Future<bool> sendOtp(String recipient, {String purpose = 'login'}) async {
    return true;
  }

  @override
  Future<UserEntity?> verifyOtp(String recipient, String code, {String? fullName}) async {
    final cleanRecipient = recipient.trim();
    var user = await getUserByEmailOrPhone(cleanRecipient);
    if (user == null) {
      final name = fullName ?? (cleanRecipient.contains('@') ? cleanRecipient.split('@').first : 'User (${cleanRecipient.length > 4 ? cleanRecipient.substring(cleanRecipient.length - 4) : cleanRecipient})');
      final isEmail = cleanRecipient.contains('@');
      final newUser = UserEntity(
        fullName: name,
        email: isEmail ? cleanRecipient : 'user_$cleanRecipient@apnapos.com',
        phoneNumber: isEmail ? 'no_phone_${DateTime.now().millisecondsSinceEpoch}' : cleanRecipient,
        password: '1234',
        createdAt: DateTime.now().toIso8601String(),
      );
      user = await registerUser(newUser);
    } else if (user.id != null) {
      await saveSession(user.id!);
    }
    return user;
  }
}

