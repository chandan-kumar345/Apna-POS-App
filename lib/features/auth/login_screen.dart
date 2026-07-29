import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import 'signup_screen.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import '../dashboard/main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'owner@apnapos.com');
  final _passwordController = TextEditingController(text: '123456');
  final _pinController = TextEditingController();

  bool _isPinLogin = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final db = DatabaseService();

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool success = false;
      if (_isPinLogin) {
        if (_pinController.text.trim().isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your 4-digit Staff PIN';
            _isLoading = false;
          });
          return;
        }
        success = await db.loginWithPin(_pinController.text.trim());
      } else {
        if (_emailController.text.trim().isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your email address';
            _isLoading = false;
          });
          return;
        }
        success = await db.loginUser(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }

      if (!mounted) return;

      if (success) {
        final rest = db.restaurant;
        if (rest != null && rest.isOnboarded) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainLayout()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RestaurantOnboardingScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid credentials. Default: owner@apnapos.com / 123456 or PIN 1234';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121318),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top 3D Carved Recessed Icon Boxes (Security Shield & User Badge)
                  Row(
                    children: [
                      _buildCarvedIconBox(
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Icon(Icons.verified_user_rounded, size: 36, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _buildCarvedIconBox(
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Icon(Icons.account_circle_rounded, size: 36, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // Title & Welcome Subtitle
                  const Text(
                    "Let's sign you in",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Welcome back,\nYou've been missed!",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Mode Toggle Button (Email/Password vs 4-Digit Staff PIN)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isPinLogin ? 'Quick Staff PIN Mode' : 'Account Credentials Mode',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isPinLogin = !_isPinLogin),
                        child: Text(
                          _isPinLogin ? 'Use Email / Password' : 'Use Staff PIN',
                          style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Error Message Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Form Input Fields (3D Recessed Dark Style)
                  if (_isPinLogin) ...[
                    _buildDarkRecessedTextField(
                      controller: _pinController,
                      hintText: 'Enter 4-Digit Staff PIN',
                      prefixIcon: Icons.pin_rounded,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                    ),
                  ] else ...[
                    _buildDarkRecessedTextField(
                      controller: _emailController,
                      hintText: 'Phone number or Email',
                      prefixIcon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildDarkRecessedTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Account Registration Link
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: RichText(
                        text: const TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          children: [
                            TextSpan(
                              text: "Register",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Full Width Primary "Sign in" Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF2563EB).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            "Sign in",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarvedIconBox(Widget iconWidget) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF13141A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF22242E), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0C0D11),
            offset: Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Color(0xFF1E202A),
            offset: Offset(-2, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Center(child: iconWidget),
    );
  }

  Widget _buildDarkRecessedTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181921),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2D3A)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF9CA3AF), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          isDense: true,
        ),
      ),
    );
  }
}
