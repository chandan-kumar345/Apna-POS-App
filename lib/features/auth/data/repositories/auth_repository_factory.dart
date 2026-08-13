import '../../domain/repositories/i_auth_repository.dart';
import 'firebase_auth_repository.dart';

enum AuthRepositoryMode {
  firebase,
}

/// Factory and provider manager for [IAuthRepository] implementation selection.
class AuthRepositoryFactory {
  static AuthRepositoryMode currentMode = AuthRepositoryMode.firebase;
  static IAuthRepository? _firebaseInstance;

  /// Returns active implementation of [IAuthRepository] (FirebaseAuthRepository)
  static IAuthRepository get instance {
    _firebaseInstance ??= FirebaseAuthRepository();
    return _firebaseInstance!;
  }

  /// Sets the authentication repository mode dynamically
  static void setMode(AuthRepositoryMode mode) {
    currentMode = mode;
  }
}
