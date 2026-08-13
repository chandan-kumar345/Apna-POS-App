import '../../domain/repositories/i_auth_repository.dart';
import 'mongo_auth_repository.dart';
import 'api_auth_repository.dart';
import 'firebase_auth_repository.dart';

enum AuthRepositoryMode {
  firebase,
  mongodb,
  apiBackend,
}

/// Factory and provider manager for [IAuthRepository] implementation selection.
class AuthRepositoryFactory {
  static AuthRepositoryMode currentMode = AuthRepositoryMode.firebase;

  static IAuthRepository _mongoInstance = MongoAuthRepository();
  static IAuthRepository _apiInstance = ApiAuthRepository();
  static IAuthRepository? _firebaseInstance;

  /// Returns active implementation of [IAuthRepository] based on [currentMode]
  static IAuthRepository get instance {
    switch (currentMode) {
      case AuthRepositoryMode.mongodb:
        return _mongoInstance;
      case AuthRepositoryMode.apiBackend:
        return _apiInstance;
      case AuthRepositoryMode.firebase:
      default:
        _firebaseInstance ??= FirebaseAuthRepository();
        return _firebaseInstance!;
    }
  }

  /// Sets the authentication repository mode dynamically
  static void setMode(AuthRepositoryMode mode) {
    currentMode = mode;
  }
}
