import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../onboarding/restaurant_onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController(text: '1234');

  bool _isLoading = false;
  String? _errorMessage;
  final db = DatabaseService();

  Future<void> _handleSignup() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await db.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        pin: _pinController.text.trim().isEmpty ? '1234' : _pinController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RestaurantOnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Signup failed: ${e.toString()}');
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
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Register Restaurant',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set up your owner account for Apna POS',
                      style: TextStyle(fontSize: 14, color: GlassTheme.textMedium),
                    ),
                    const SizedBox(height: 28),
                    GlassContainer(
                      padding: const EdgeInsets.all(28),
                      borderRadius: 24,
                      blurStrength: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          GlassTextField(
                            controller: _nameController,
                            labelText: 'Owner Full Name',
                            hintText: 'e.g. Ramesh Sharma',
                            prefixIcon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          GlassTextField(
                            controller: _emailController,
                            labelText: 'Email Address',
                            hintText: 'owner@apnapos.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          GlassTextField(
                            controller: _passwordController,
                            labelText: 'Password',
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          GlassTextField(
                            controller: _pinController,
                            labelText: '4-Digit Staff Quick PIN',
                            hintText: '1234',
                            prefixIcon: Icons.pin_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 28),
                          GlassButton(
                            label: 'Create Account & Continue',
                            icon: Icons.check_circle_outline,
                            onPressed: _handleSignup,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Already registered? ",
                                style: TextStyle(color: GlassTheme.textMedium, fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  "Sign In",
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
