import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_user_model.dart';
import '../../services/super_admin_auth_service.dart';

import '../dashboard/super_admin_dashboard_screen.dart';
import '../../widgets/super_admin_layout.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const SuperAdminLoginScreen({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final _emailController = TextEditingController(text: 'superadmin@apnapos.com');
  final _passwordController = TextEditingController(text: 'Admin@2026');
  final _otpController = TextEditingController();
  bool _requireOtp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  SuperAdminRole _selectedRole = SuperAdminRole.superAdmin;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SuperAdminTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: SuperAdminTheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: SuperAdminTheme.cardShadow,
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Logo & Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SuperAdminTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: SuperAdminTheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Apna POSS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: SuperAdminTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Web Super Admin Console',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SuperAdminTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Sign In to Super Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your administrative credentials to manage subscriptions, businesses, and platform revenue.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SuperAdminTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: SuperAdminTheme.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: SuperAdminTheme.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Role Selector
                const Text(
                  'Administrative Role',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: SuperAdminTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SuperAdminTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SuperAdminRole>(
                      value: _selectedRole,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
                      items: SuperAdminRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text('${role.label} (${role.description.split(" ").first})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Email Input
                const Text(
                  'Admin Email',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, size: 18, color: SuperAdminTheme.textMuted),
                    hintText: 'admin@apnapos.com',
                    filled: true,
                    fillColor: SuperAdminTheme.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SuperAdminTheme.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Input
                const Text(
                  'Password',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: SuperAdminTheme.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: SuperAdminTheme.textMuted),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    hintText: '••••••••',
                    filled: true,
                    fillColor: SuperAdminTheme.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SuperAdminTheme.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),

                if (_requireOtp) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '2FA Authenticator Code',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.security_rounded, size: 18, color: SuperAdminTheme.primary),
                      hintText: '123456',
                      filled: true,
                      fillColor: SuperAdminTheme.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SuperAdminTheme.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SuperAdminTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Access Super Admin Dashboard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),

                const Center(
                  child: Text(
                    'Protected SaaS Portal • Enterprise 256-bit Encryption',
                    style: TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 450));

    final session = SuperAdminSession();
    session.login(
      email: email,
      password: password,
      role: _selectedRole,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SuperAdminLayout()),
        );
      }
    }
  }
}
