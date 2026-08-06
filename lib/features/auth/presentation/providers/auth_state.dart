import '../../../../core/models/user_model.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  sessionExpired,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(UserModel user) => AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.unauthenticated() => const AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.sessionExpired(String message) => AuthState(status: AuthStatus.sessionExpired, errorMessage: message);
  factory AuthState.error(String message) => AuthState(status: AuthStatus.error, errorMessage: message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => status.hashCode ^ user.hashCode ^ errorMessage.hashCode;
}
