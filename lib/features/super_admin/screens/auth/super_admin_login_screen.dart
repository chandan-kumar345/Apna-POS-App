import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_user_model.dart';
import '../../services/super_admin_auth_service.dart';

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
  final bool _requireOtp = false;
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: SuperAdminTheme.headerGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    offset: const Offset(-4, -4),
                    blurRadius: 16,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(8, 20),
                    blurRadius: 36,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Logo & Highlighted Brand Header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: SuperAdminTheme.primary,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Apna POS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                            ),
                            child: const Text(
                              'SUPER ADMIN CONSOLE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0052FF),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Administrative Sign In',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your administrative credentials to manage subscriptions, businesses, and platform revenue.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SuperAdminTheme.dangerLight,
                        borderRadius: BorderRadius.circular(12),
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

                  // Administrative Role Selector
                  const Text(
                    'Administrative Role',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: SuperAdminTheme.insetBox(radius: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SuperAdminRole>(
                        value: _selectedRole,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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

                  // Admin Email Input
                  const Text(
                    'Admin Email',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: SuperAdminTheme.insetBox(radius: 12),
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                        hintText: 'admin@apnapos.com',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  const Text(
                    'Password',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: SuperAdminTheme.insetBox(radius: 12),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: const Color(0xFF64748B)),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        hintText: '••••••••',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  if (_requireOtp) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '2FA Authenticator Code',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: SuperAdminTheme.insetBox(radius: 12),
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14, letterSpacing: 4, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.security_rounded, size: 18, color: SuperAdminTheme.primary),
                          hintText: '123456',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Submit Gradient Button (Pill shape with raised shadow)
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: SuperAdminTheme.primaryButtonGradient,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: SuperAdminTheme.raisedButtonShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _handleLogin,
                        borderRadius: BorderRadius.circular(26),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                              : const Text(
                                  'Access Super Admin Dashboard',
                                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Center(
                    child: Text(
                      'Protected SaaS Portal • Enterprise 256-bit Encryption',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
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

