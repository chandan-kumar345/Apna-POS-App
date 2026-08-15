import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;

  final FlutterSecureStorage _storage;

  // In-memory cache for instant zero-latency retrieval
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;
  static String? _cachedUserId;
  static String? _cachedDeviceId;

  SecureStorageService._internal()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
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
    _cachedAccessToken = token;
    try {
      await _storage.write(key: _accessTokenKey, value: token);
    } catch (e) {
      debugPrint('SecureStorage write warning: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, token);
    } catch (_) {}
  }

  @override
  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    try {
      final token = await _storage.read(key: _accessTokenKey);
      if (token != null && token.isNotEmpty) {
        _cachedAccessToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('SecureStorage read warning: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupToken = prefs.getString(_accessTokenKey);
      if (backupToken != null && backupToken.isNotEmpty) {
        _cachedAccessToken = backupToken;
        return backupToken;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _cachedRefreshToken = token;
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      debugPrint('SecureStorage write refresh warning: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_refreshTokenKey, token);
    } catch (_) {}
  }

  @override
  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    try {
      final token = await _storage.read(key: _refreshTokenKey);
      if (token != null && token.isNotEmpty) {
        _cachedRefreshToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('SecureStorage read refresh warning: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupToken = prefs.getString(_refreshTokenKey);
      if (backupToken != null && backupToken.isNotEmpty) {
        _cachedRefreshToken = backupToken;
        return backupToken;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveDeviceId(String deviceId) async {
    _cachedDeviceId = deviceId;
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    } catch (_) {}
  }

  @override
  Future<String?> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId;
    try {
      final id = await _storage.read(key: _deviceIdKey);
      _cachedDeviceId = id;
      return id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveUserId(String userId) async {
    _cachedUserId = userId;
    try {
      await _storage.write(key: _userIdKey, value: userId);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
    } catch (_) {}
  }

  @override
  Future<String?> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    try {
      final id = await _storage.read(key: _userIdKey);
      if (id != null) {
        _cachedUserId = id;
        return id;
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (_) {}
    return null;
  }

  @override
  Future<void> clearAll() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedUserId = null;
    _cachedDeviceId = null;
    try {
      await _storage.deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
    } catch (_) {}
  }
}
