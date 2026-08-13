import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../../../api/auth_api.dart';
import '../../../../core/services/session_manager.dart';

/// REST API implementation of [IAuthRepository] interfacing with Node.js backend.
class ApiAuthRepository implements IAuthRepository {
  final AuthApi _authApi;
  final SessionManager _sessionManager;

  ApiAuthRepository({
    AuthApi? authApi,
    SessionManager? sessionManager,
  })  : _authApi = authApi ?? AuthApi(),
        _sessionManager = sessionManager ?? SessionManager();

  @override
  Future<UserEntity> registerUser(UserEntity user) async {
    final response = await _authApi.register(
      name: user.fullName,
      email: user.email,
      phone: user.phoneNumber,
      password: user.password,
    );

    final userData = response['user'];
    final userEntity = UserEntity(
      id: userData['id'] is int ? userData['id'] : DateTime.now().millisecondsSinceEpoch,
      fullName: userData['name'] ?? user.fullName,
      email: userData['email'] ?? user.email,
      phoneNumber: userData['phone'] ?? user.phoneNumber,
      password: user.password,
      pinCode: user.pinCode,
    );

    if (userEntity.id != null) {
      await saveSession(userEntity.id!);
    }
    return userEntity;
  }

  @override
  Future<UserEntity?> login(String identifier, String password) async {
    final response = await _authApi.login(
      identifier: identifier,
      password: password,
    );

    final userData = response['user'];
    final userEntity = UserEntity(
      id: userData['id'] is int ? userData['id'] : DateTime.now().millisecondsSinceEpoch,
      fullName: userData['name'] ?? 'Apna POS User',
      email: userData['email'] ?? (identifier.contains('@') ? identifier : ''),
      phoneNumber: userData['phone'] ?? (!identifier.contains('@') ? identifier : ''),
      password: password,
      pinCode: '1234',
    );

    if (userEntity.id != null) {
      await saveSession(userEntity.id!);
    }
    return userEntity;
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    return false;
  }

  @override
  Future<bool> checkPhoneExists(String phoneNumber) async {
    return false;
  }

  @override
  Future<UserEntity?> getUserById(int id) async {
    return null;
  }

  @override
  Future<UserEntity?> getUserByEmailOrPhone(String identifier) async {
    return null;
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
    try {
      await _authApi.sendOtp(phone: recipient, purpose: purpose);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<UserEntity?> verifyOtp(String recipient, String code, {String? fullName}) async {
    final response = await _authApi.verifyOtp(
      phone: recipient,
      otp: code,
      name: fullName,
    );

    final userData = response['user'];
    final userEntity = UserEntity(
      id: userData['id'] is int ? userData['id'] : DateTime.now().millisecondsSinceEpoch,
      fullName: userData['name'] ?? fullName ?? 'User ${recipient.substring(recipient.length > 4 ? recipient.length - 4 : 0)}',
      email: userData['email'] ?? 'user_$recipient@apnapos.com',
      phoneNumber: userData['phone'] ?? recipient,
      password: '1234',
      pinCode: '1234',
    );

    if (userEntity.id != null) {
      await saveSession(userEntity.id!);
    }
    return userEntity;
  }
}
