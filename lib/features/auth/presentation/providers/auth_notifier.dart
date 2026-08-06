import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/security/device_integrity_service.dart';
import '../../../../core/database/database_service.dart';

final secureStorageProvider = Provider<ISecureStorageService>((ref) {
  return SecureStorageService();
});

final deviceIntegrityProvider = Provider<IDeviceIntegrityService>((ref) {
  return DeviceIntegrityService();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    secureStorage: ref.watch(secureStorageProvider),
    deviceIntegrity: ref.watch(deviceIntegrityProvider),
    dbService: DatabaseService(),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ISecureStorageService _secureStorage;
  final IDeviceIntegrityService _deviceIntegrity;
  final DatabaseService _dbService;

  AuthNotifier({
    required ISecureStorageService secureStorage,
    required IDeviceIntegrityService deviceIntegrity,
    required DatabaseService dbService,
  })  : _secureStorage = secureStorage,
        _deviceIntegrity = deviceIntegrity,
        _dbService = dbService,
        super(AuthState.initial()) {
    checkAutoLogin();
  }

  Future<void> checkAutoLogin() async {
    state = AuthState.loading();
    
    // Enforce security integrity check first
    await _deviceIntegrity.enforceSecurityChecks();

    final accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      final user = _dbService.currentUser;
      if (user != null) {
        state = AuthState.authenticated(user);
        return;
      }
    }
    state = AuthState.unauthenticated();
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    final success = await _dbService.loginUser(email, password);
    if (success && _dbService.currentUser != null) {
      final user = _dbService.currentUser!;
      
      // Store tokens securely in EncryptedSharedPreferences / Keychain
      await _secureStorage.saveAccessToken('JWT_ACCESS_TOKEN_${DateTime.now().millisecondsSinceEpoch}');
      await _secureStorage.saveRefreshToken('JWT_REFRESH_TOKEN_${DateTime.now().millisecondsSinceEpoch}');
      await _secureStorage.saveUserId(user.id);
      
      state = AuthState.authenticated(user);
    } else {
      state = AuthState.error('Invalid credentials or account locked.');
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    await _secureStorage.clearAll();
    await _dbService.logout();
    state = AuthState.unauthenticated();
  }
}
