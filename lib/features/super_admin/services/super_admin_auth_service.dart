import 'package:flutter/material.dart';
import '../models/super_admin_user_model.dart';

class SuperAdminSession extends ChangeNotifier {
  static final SuperAdminSession _instance = SuperAdminSession._internal();
  factory SuperAdminSession() => _instance;
  SuperAdminSession._internal();

  bool _isAuthenticated = true; // Set authenticated for direct access or login gate
  final String _adminId = 'adm_001';
  String _adminName = 'Chandan SuperAdmin';
  String _adminEmail = 'superadmin@apnapos.com';
  SuperAdminRole _currentRole = SuperAdminRole.superAdmin;
  String _authToken = 'sa_session_live_token_779';

  bool get isAuthenticated => _isAuthenticated;
  String get adminId => _adminId;
  String get adminName => _adminName;
  String get adminEmail => _adminEmail;
  SuperAdminRole get currentRole => _currentRole;
  String get authToken => _authToken;

  void login({
    required String email,
    required String password,
    String? otp,
    SuperAdminRole role = SuperAdminRole.superAdmin,
  }) {
    _isAuthenticated = true;
    _adminEmail = email;
    _adminName = email.split('@').first.toUpperCase();
    _currentRole = role;
    _authToken = 'sa_token_${DateTime.now().millisecondsSinceEpoch}';
    notifyListeners();
  }

  void switchRole(SuperAdminRole newRole) {
    _currentRole = newRole;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _authToken = '';
    notifyListeners();
  }
}
