import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ISecureStorageService {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> saveDeviceId(String deviceId);
  Future<String?> getDeviceId();
  Future<void> saveUserId(String userId);
  Future<String?> getUserId();
  Future<void> clearAll();
}

class SecureStorageService implements ISecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
            resetOnError: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
            synchronizable: false,
          ),
        );

  static const String _accessTokenKey = 'SEC_KEY_AT_V1';
  static const String _refreshTokenKey = 'SEC_KEY_RT_V1';
  static const String _deviceIdKey = 'SEC_KEY_DID_V1';
  static const String _userIdKey = 'SEC_KEY_UID_V1';

  @override
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  @override
  Future<String?> getDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }

  @override
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  @override
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  @override
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
