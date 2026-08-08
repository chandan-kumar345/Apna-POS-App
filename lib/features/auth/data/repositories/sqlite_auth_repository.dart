import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../../../core/database/user_database_helper.dart';
import '../../../../core/services/session_manager.dart';

/// Concrete implementation of [IAuthRepository] using SQLite via [UserDatabaseHelper]
/// and session management via [SessionManager].
class SqliteAuthRepository implements IAuthRepository {
  final UserDatabaseHelper _dbHelper;
  final SessionManager _sessionManager;

  SqliteAuthRepository({
    UserDatabaseHelper? dbHelper,
    SessionManager? sessionManager,
  })  : _dbHelper = dbHelper ?? UserDatabaseHelper(),
        _sessionManager = sessionManager ?? SessionManager();

  @override
  Future<UserEntity> registerUser(UserEntity user) async {
    try {
      // 1. Field Validation
      if (user.fullName.trim().isEmpty) {
        throw Exception('Full Name is required');
      }
      if (user.email.trim().isEmpty || !user.email.contains('@')) {
        throw Exception('A valid email address is required');
      }
      if (user.phoneNumber.trim().isEmpty) {
        throw Exception('Phone number is required');
      }
      if (user.password.trim().isEmpty) {
        throw Exception('Password is required');
      }

      // 2. Check duplicate email or phone number in SQLite
      final isEmailTaken = await _dbHelper.emailExists(user.email);
      if (isEmailTaken) {
        throw Exception('This email address is already registered. Please login.');
      }

      final isPhoneTaken = await _dbHelper.phoneExists(user.phoneNumber);
      if (isPhoneTaken) {
        throw Exception('This phone number is already registered. Please login.');
      }

      // 3. Insert into SQLite Database
      final insertedId = await _dbHelper.insertUserEntity(user);
      final createdUser = user.copyWith(id: insertedId);

      return createdUser;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserEntity?> login(String identifier, String password) async {
    final cleanId = identifier.trim();
    final cleanPw = password.trim();

    if (cleanId.isEmpty || cleanPw.isEmpty) {
      throw Exception('Please enter both identifier and password');
    }

    // Retrieve user from SQLite DB by email or phone
    final user = await _dbHelper.getUserByEmailOrPhone(cleanId);

    if (user == null) {
      throw Exception('Account not found. Please register first.');
    }

    // Verify Password match
    if (user.password != cleanPw) {
      throw Exception('Invalid password. Please check your credentials.');
    }

    // Save login session state in SharedPreferences
    if (user.id != null) {
      await saveSession(user.id!);
    }

    return user;
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    return await _dbHelper.emailExists(email);
  }

  @override
  Future<bool> checkPhoneExists(String phoneNumber) async {
    return await _dbHelper.phoneExists(phoneNumber);
  }

  @override
  Future<UserEntity?> getUserById(int id) async {
    return await _dbHelper.getUserById(id);
  }

  @override
  Future<UserEntity?> getUserByEmailOrPhone(String identifier) async {
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
}
