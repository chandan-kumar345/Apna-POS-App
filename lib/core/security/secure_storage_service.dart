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
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;

  final FlutterSecureStorage _storage;
  Future<SharedPreferences> Function() _preferences =
      SharedPreferences.getInstance;
  Future<void>? _loading;

  @visibleForTesting
  SecureStorageService.forTesting({
    required FlutterSecureStorage storage,
    required Future<SharedPreferences> Function() preferences,
    // Public injection argument; keep the backing field private.
    // ignore: prefer_initializing_formals
  }) : _storage = storage {
    _preferences = preferences;
  }

  // In-memory cache for instant zero-latency retrieval
  bool _isLoaded = false;
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedUserId;
  String? _cachedDeviceId;
  String? _cachedBusinessId;

  SecureStorageService._internal()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: true),
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

  Future<void> _ensureLoaded() {
    if (_isLoaded) return Future.value();
    return _loading ??= _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await _preferences();
      _cachedAccessToken ??= prefs.getString(_accessTokenKey);
      _cachedRefreshToken ??= prefs.getString(_refreshTokenKey);
      _cachedUserId ??= prefs.getString(_userIdKey);
      _cachedDeviceId ??= prefs.getString(_deviceIdKey);
      _cachedBusinessId ??=
          prefs.getString(_businessIdKey) ??
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
    } finally {
      _isLoaded = true;
      _loading = null;
    }
  }

  @override
  Future<void> saveAccessToken(String token) async {
    await _ensureLoaded();
    _cachedAccessToken = token;
    try {
      final prefs = await _preferences();
      await prefs.setString(_accessTokenKey, token);
    } catch (_) {}
    try {
      await _storage.write(key: _accessTokenKey, value: token);
    } catch (e) {
      debugPrint('SecureStorage write warning: $e');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    if (!_isLoaded) await _ensureLoaded();
    return _cachedAccessToken;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _ensureLoaded();
    _cachedRefreshToken = token;
    try {
      final prefs = await _preferences();
      await prefs.setString(_refreshTokenKey, token);
    } catch (_) {}
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      debugPrint('SecureStorage write refresh warning: $e');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    if (!_isLoaded) await _ensureLoaded();
    return _cachedRefreshToken;
  }

  @override
  Future<void> saveDeviceId(String deviceId) async {
    await _ensureLoaded();
    _cachedDeviceId = deviceId;
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    } catch (_) {}
    try {
      final prefs = await _preferences();
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
    await _ensureLoaded();
    _cachedUserId = userId;
    try {
      await _storage.write(key: _userIdKey, value: userId);
    } catch (_) {}
    try {
      final prefs = await _preferences();
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
    await _ensureLoaded();
    _cachedBusinessId = businessId;
    try {
      await _storage.write(key: _businessIdKey, value: businessId);
    } catch (_) {}
    try {
      final prefs = await _preferences();
      await prefs.setString(_businessIdKey, businessId);
    } catch (_) {}
  }

  Future<void> savePushToken(String token) async {
    try {
      final prefs = await _preferences();
      await prefs.setString('SEC_KEY_PUSH_TOKEN_V1', token);
    } catch (_) {}
  }

  Future<String?> getPushToken() async {
    try {
      final prefs = await _preferences();
      return prefs.getString('SEC_KEY_PUSH_TOKEN_V1');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getBusinessId() async {
    if (!_isLoaded) await _ensureLoaded();
    return _cachedBusinessId;
  }

  @override
  Future<void> clearAll() async {
    // Finish any pending read before clearing, so it cannot restore old tokens.
    await _loading;
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
      final prefs = await _preferences();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_businessIdKey);
    } catch (_) {}
  }
}
