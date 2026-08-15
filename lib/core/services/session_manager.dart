import 'package:flutter/foundation.dart';
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
  Future<void> saveSession(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, userId);
    } catch (e) {
      debugPrint('SessionManager saveSession error: $e');
    }
  }

  /// Checks if a user is currently logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      debugPrint('SessionManager isLoggedIn error: $e');
      return false;
    }
  }

  /// Retrieves the active logged-in user ID safely without throwing type cast errors
  Future<String?> getLoggedInUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.get(_keyUserId);
      if (val == null) return null;
      return val.toString();
    } catch (e) {
      debugPrint('SessionManager getLoggedInUserId error: $e');
      return null;
    }
  }

  /// Clears active session state on logout
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
    } catch (e) {
      debugPrint('SessionManager clearSession error: $e');
    }
  }
}
