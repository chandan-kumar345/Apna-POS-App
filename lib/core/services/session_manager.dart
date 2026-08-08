import 'package:shared_preferences/shared_preferences.dart';

/// Manages local user login session state using SharedPreferences.
/// ONLY stores session state flags (is_logged_in, active_user_id), not user credentials or full user details.
class SessionManager {
  static const String _keyIsLoggedIn = 'apna_pos_is_logged_in';
  static const String _keyUserId = 'apna_pos_active_user_id';

  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  /// Saves session state in SharedPreferences
  Future<void> saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setInt(_keyUserId, userId);
  }

  /// Checks if a user is currently logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Retrieves the active logged-in user ID
  Future<int?> getLoggedInUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  /// Clears active session state on logout
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
  }
}
