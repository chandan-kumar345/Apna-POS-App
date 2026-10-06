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
  Future<void> saveBusinessId(String businessId);
  Future<String?> getBusinessId();
  Future<void> clearAll();
}

class SecureStorageService implements ISecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;

  final FlutterSecureStorage _storage;

  // In-memory cache for instant zero-latency retrieval
  static bool _isLoaded = false;
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;
  static String? _cachedUserId;
  static String? _cachedDeviceId;
  static String? _cachedBusinessId;

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
  static const String _businessIdKey = 'SEC_KEY_BID_V1';

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    _isLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedAccessToken ??= prefs.getString(_accessTokenKey);
      _cachedRefreshToken ??= prefs.getString(_refreshTokenKey);
      _cachedUserId ??= prefs.getString(_userIdKey);
      _cachedDeviceId ??= prefs.getString(_deviceIdKey);
      _cachedBusinessId ??= prefs.getString(_businessIdKey) ??
          prefs.getString('business_id') ??
          prefs.getString('apna_pos_business_id');
    } catch (_) {}

    try {
      if (_cachedAccessToken == null || _cachedAccessToken!.isEmpty) {
        final token = await _storage.read(key: _accessTokenKey);
        if (token != null && token.isNotEmpty) _cachedAccessToken = token;
      }
      if (_cachedRefreshToken == null || _cachedRefreshToken!.isEmpty) {
        final rToken = await _storage.read(key: _refreshTokenKey);
        if (rToken != null && rToken.isNotEmpty) _cachedRefreshToken = rToken;
      }
      if (_cachedUserId == null || _cachedUserId!.isEmpty) {
        final uId = await _storage.read(key: _userIdKey);
        if (uId != null && uId.isNotEmpty) _cachedUserId = uId;
      }
      if (_cachedDeviceId == null || _cachedDeviceId!.isEmpty) {
        final dId = await _storage.read(key: _deviceIdKey);
        if (dId != null && dId.isNotEmpty) _cachedDeviceId = dId;
      }
      if (_cachedBusinessId == null || _cachedBusinessId!.isEmpty) {
        final bId = await _storage.read(key: _businessIdKey);
        if (bId != null && bId.isNotEmpty) _cachedBusinessId = bId;
      }
    } catch (e) {
      debugPrint('SecureStorage initial read info: $e');
    }
  }

  @override
  Future<void> saveAccessToken(String token) async {
    _cachedAccessToken = token;
    _isLoaded = true;
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
    if (!_isLoaded) await _ensureLoaded();
    return _cachedAccessToken;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    _cachedRefreshToken = token;
    _isLoaded = true;
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
    if (!_isLoaded) await _ensureLoaded();
    return _cachedRefreshToken;
  }

  @override
  Future<void> saveDeviceId(String deviceId) async {
    _cachedDeviceId = deviceId;
    _isLoaded = true;
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, deviceId);
    } catch (_) {}
  }

  @override
  Future<String?> getDeviceId() async {
    if (!_isLoaded) await _ensureLoaded();
    return _cachedDeviceId;
  }

  @override
  Future<void> saveUserId(String userId) async {
    _cachedUserId = userId;
    _isLoaded = true;
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
    if (!_isLoaded) await _ensureLoaded();
    return _cachedUserId;
  }

  @override
  Future<void> saveBusinessId(String businessId) async {
    _cachedBusinessId = businessId;
    _isLoaded = true;
    try {
      await _storage.write(key: _businessIdKey, value: businessId);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_businessIdKey, businessId);
    } catch (_) {}
  }

  @override
  Future<String?> getBusinessId() async {
    if (!_isLoaded) await _ensureLoaded();
    return _cachedBusinessId;
  }

  @override
  Future<void> clearAll() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedUserId = null;
    _cachedDeviceId = null;
    _cachedBusinessId = null;
    _isLoaded = true;
    try {
      await _storage.deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_businessIdKey);
    } catch (_) {}
  }
}
