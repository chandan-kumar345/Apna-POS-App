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
          _errorMessage = 'Invalid credentials or PIN. Try PIN 1234';
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
      body: SafeArea(
        child: Container(
          decoration: GlassTheme.backgroundDecoration,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Brand Logo & Title
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: GlassTheme.primaryViolet.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: GlassTheme.primaryViolet.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: GlassTheme.primaryViolet.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.point_of_sale_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Apna POS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Smart Glassmorphic Restaurant Management',
                      style: TextStyle(
                        fontSize: 14,
                        color: GlassTheme.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Glassmorphic Login Form Card
                    GlassContainer(
                      padding: const EdgeInsets.all(28),
                      borderRadius: 24,
                      blurStrength: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tab Selector
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: GlassTheme.glassInput,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isPinLogin = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isPinLogin ? GlassTheme.primaryViolet : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Owner / Manager',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: !_isPinLogin ? Colors.white : GlassTheme.textMedium,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isPinLogin = true),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isPinLogin ? GlassTheme.primaryViolet : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Staff Quick PIN',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _isPinLogin ? Colors.white : GlassTheme.textMedium,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: GlassTheme.accentRose.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: GlassTheme.accentRose.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: GlassTheme.accentRose, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          if (!_isPinLogin) ...[
                            GlassTextField(
                              controller: _emailController,
                              labelText: 'Email Address',
                              hintText: 'name@restaurant.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            GlassTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: GlassTheme.textMedium,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ] else ...[
                            GlassTextField(
                              controller: _pinController,
                              labelText: '4-Digit Staff PIN',
                              hintText: 'Enter PIN (e.g. 1234)',
                              prefixIcon: Icons.pin_outlined,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                            ),
                          ],

                          const SizedBox(height: 28),

                          GlassButton(
                            label: _isPinLogin ? 'Quick Access POS' : 'Sign In to Apna POS',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _handleLogin,
                            isLoading: _isLoading,
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "New Restaurant? ",
                                style: TextStyle(color: GlassTheme.textMedium, fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                                  );
                                },
                                child: const Text(
                                  "Create Account",
                                  style: TextStyle(
                                    color: GlassTheme.primaryCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
