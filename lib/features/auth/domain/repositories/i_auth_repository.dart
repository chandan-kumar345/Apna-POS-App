import '../entities/user_entity.dart';

/// Abstract repository interface for authentication and user persistence operations.
/// Follows Clean Architecture to allow seamless migration to Firebase, REST API, or other backend sources.
abstract class IAuthRepository {
  /// Registers a new user into storage. Returns [UserEntity] on success.
  /// Throws Exception if validation fails or duplicate credentials exist.
  Future<UserEntity> registerUser(UserEntity user);

  /// Authenticates user using either Email + Password OR Phone Number + Password.
  Future<UserEntity?> login(String identifier, String password);

  /// Checks if an email address is already registered in storage.
  Future<bool> checkEmailExists(String email);

  /// Checks if a phone number is already registered in storage.
  Future<bool> checkPhoneExists(String phoneNumber);

  /// Gets user record by unique identifier ID.
  Future<UserEntity?> getUserById(String id);

  /// Gets user record by email or phone number.
  Future<UserEntity?> getUserByEmailOrPhone(String identifier);

  /// Checks if a active login session exists in SharedPreferences.
  Future<bool> isSessionLoggedIn();

  /// Gets currently logged-in user ID from session.
  Future<String?> getLoggedInUserId();

  /// Saves user login session state to SharedPreferences (only stores session state, not user credentials).
  Future<void> saveSession(String userId);

  /// Clears the login session state from SharedPreferences.
  Future<void> clearSession();

  /// Sends OTP to specified recipient (email or phone).
  Future<bool> sendOtp(String recipient, {String purpose = 'login'});

  /// Verifies OTP code for specified recipient and logs in or registers user.
  Future<UserEntity?> verifyOtp(String recipient, String code, {String? fullName});
}

