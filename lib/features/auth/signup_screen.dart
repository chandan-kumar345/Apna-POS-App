import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../../core/services/email_service.dart';
import '../../core/services/network_service.dart';
import '../../core/utils/form_validators.dart';
import '../../core/widgets/otp_pin_input.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import 'create_profile_screen.dart';
import '../dashboard/main_layout.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

// Standalone Register Form Widget (Embedded inline inside LoginScreen or used standalone)
class RegisterFormWidget extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;
  final String? initialPhone;
  final VoidCallback? onSwitchToLogin;

  const RegisterFormWidget({
    super.key,
    this.initialEmail,
    this.initialPassword,
    this.initialPhone,
    this.onSwitchToLogin,
  });

  @override
  State<RegisterFormWidget> createState() => _RegisterFormWidgetState();
}

class _RegisterFormWidgetState extends State<RegisterFormWidget> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  final db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _passwordController = TextEditingController(text: widget.initialPassword ?? '');
  }

  @override
  void didUpdateWidget(covariant RegisterFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEmail != null &&
        widget.initialEmail != oldWidget.initialEmail &&
        _emailController.text.trim().isEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialPassword != null &&
        widget.initialPassword != oldWidget.initialPassword &&
        _passwordController.text.trim().isEmpty) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _handleGoogleSignup() async {
    final hasConn = await NetworkService().hasInternet();
    if (!hasConn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Internet connection required to sign up with Google.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
      if (googleAccount != null) {
        final email = googleAccount.email;
        final name = googleAccount.displayName ?? email.split('@').first;
        final photoUrl = googleAccount.photoUrl;

        final success = await db.loginWithGoogle(email, name, photoUrl);
        if (!mounted) return;
        if (success) {
          final rest = db.restaurant;
          if (rest != null && rest.isOnboarded) {
            Navigator.pushAndRemoveUntil(
              context,
              SlideUpPageRoute(page: const MainLayout()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              SlideUpPageRoute(page: const RestaurantOnboardingScreen()),
              (route) => false,
            );
          }
          return;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to sign up with Google')),
          );
        }
      }
    } catch (e) {
      debugPrint('Google Sign In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Trigger OTP Verification Popup when clicking "Continue"
  Future<void> _handleSignup() async {
    final emailText = _emailController.text.trim();
    final passwordText = _passwordController.text.trim();

    final emailErr = FormValidators.validateEmail(emailText);
    if (emailErr != null) {
      setState(() => _errorMessage = emailErr);
      return;
    }

    final passwordErr = FormValidators.validatePassword(passwordText);
    if (passwordErr != null) {
      setState(() => _errorMessage = passwordErr);
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    
    try {
      // Dispatch OTP Email from sooftcode@gmail.com
      await EmailService().sendOtpEmail(emailText);
    } catch (e) {
      debugPrint('OTP dispatch warning: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GlassTheme.primaryNavy,
          content: Text(
            'OTP verification code has been sent to $emailText',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      _showOtpVerificationDialog(emailText);
    }
  }


  // OTP Verification Popup Dialog with Theme Colors, Resend OTP, and Verify Button
  void _showOtpVerificationDialog(String emailText) {
    final otpController = TextEditingController();
    final otpFocusNode = FocusNode();
    String? otpError;
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22002870),
                                blurRadius: 36,
                                offset: Offset(0, 14),
                              ),
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Popup Title
                              const Text(
                                'OTP Verification',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Popup Subtitle with Email
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  text: 'Enter the 4-digit verification code sent to\n',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: emailText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Error Message inside Dialog
                              if (otpError != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: Color(0xFFEF4444), size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          otpError!,
                                          style: const TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // 4 Neumorphic Rounded OTP Input Boxes
                              OtpPinInput(
                                controller: otpController,
                                focusNode: otpFocusNode,
                                length: 4,
                                onChanged: (_) {
                                  if (otpError != null) {
                                    setDialogState(() => otpError = null);
                                  }
                                },
                              ),

                              const SizedBox(height: 18),

                              // Resend OTP Option
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Didn't receive code? ",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      setDialogState(() {
                                        otpError = null;
                                        otpController.clear();
                                      });
                                      await EmailService().sendOtpEmail(emailText);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: GlassTheme.primaryNavy,
                                            content: Text(
                                              'OTP verification code resent to $emailText',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                            ),
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Resend OTP',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0066FF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              // Verify Action Button
                              Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0066FF), Color(0xFF0052E0)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x350066FF),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: isVerifying
                                      ? null
                                      : () async {
                                          final enteredCode = otpController.text
                                              .trim()
                                              .replaceAll(RegExp(r'[^0-9]'), '');
                                          if (enteredCode.length < 4) {
                                            setDialogState(() {
                                              otpError = 'Please enter the complete 4-digit OTP code.';
                                            });
                                            return;
                                          }

                                          setDialogState(() {
                                            isVerifying = true;
                                            otpError = null;
                                          });

                                          final isOtpValid =
                                              EmailService().verifyOtp(emailText, enteredCode);

                                          if (!isOtpValid) {
                                            setDialogState(() {
                                              isVerifying = false;
                                              otpError =
                                                  'Invalid or expired OTP verification code. Please check your email or click Resend.';
                                            });
                                            return;
                                          }

                                          try {
                                            // Register user in Firebase Authentication & backend API
                                            final nameFromEmail = emailText.contains('@')
                                                ? emailText.split('@').first
                                                : emailText;
                                            final password = _passwordController.text.trim();

                                            // 1. Create or sign in user in Firebase Authentication
                                            try {
                                              final auth = FirebaseAuth.instance;
                                              UserCredential? fbCred;
                                              try {
                                                fbCred = await auth.createUserWithEmailAndPassword(
                                                  email: emailText,
                                                  password: password,
                                                );
                                              } on FirebaseAuthException catch (fbErr) {
                                                if (fbErr.code == 'email-already-in-use') {
                                                  fbCred = await auth.signInWithEmailAndPassword(
                                                    email: emailText,
                                                    password: password,
                                                  );
                                                } else {
                                                  debugPrint('[FirebaseAuth] signup warning: ${fbErr.code} - ${fbErr.message}');
                                                }
                                              }
                                              if (fbCred?.user != null) {
                                                await fbCred!.user!.updateDisplayName(nameFromEmail);
                                              }
                                            } catch (fbEx) {
                                              debugPrint('[FirebaseAuth] signup exception: $fbEx');
                                            }

                                            // 2. Register user in Backend REST API
                                            try {
                                              await AuthService().register(emailText, password);
                                            } catch (e) {
                                              if (e.toString().contains('already exists') ||
                                                  e.toString().contains('EMAIL_ALREADY_EXISTS')) {
                                                // If already registered, try logging in
                                                await AuthService().login(emailText, password);
                                              } else if (e.toString().contains('Unable to connect') ||
                                                  e.toString().contains('Connection timed out') ||
                                                  e.toString().contains('SocketException') ||
                                                  e.toString().contains('CONNECTION_ERROR')) {
                                                // Fallback to local DatabaseService user registration
                                                await DatabaseService().registerUser(
                                                  name: nameFromEmail,
                                                  email: emailText,
                                                  password: password,
                                                  pin: '1234',
                                                );
                                              } else {
                                                rethrow;
                                              }
                                            }

                                            // 3. Immediately sync user document to Cloud Firestore
                                            final activeUser = DatabaseService().currentUser;
                                            if (activeUser != null) {
                                              await FirestoreService().saveUser(activeUser);
                                            }

                                            // Clear OTP only after successful registration
                                            EmailService().clearOtp(emailText);

                                            if (!context.mounted) return;

                                            Navigator.pop(context); // Close OTP Dialog
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              SlideRightPageRoute(
                                                page: CreateProfileScreen(
                                                  initialEmail: emailText,
                                                  initialName: nameFromEmail,
                                                ),
                                              ),
                                              (route) => false,
                                            );
                                          } catch (e) {
                                            final errStr = e.toString().replaceAll('Exception:', '').trim();
                                            debugPrint('Signup error detail: $errStr');
                                            setDialogState(() {
                                              isVerifying = false;
                                              otpError = errStr;
                                            });
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child: isVerifying
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Verify',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Top-Right Close Button
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF64748B),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error Banner
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Form Input Fields (Email Address & Password)
        _buildInputCard(
          label: 'Email Address',
          hint: 'Enter email address',
          icon: Icons.mail_outline_rounded,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 10),

        _buildInputCard(
          label: 'Password',
          hint: 'Create password',
          icon: Icons.lock_outline_rounded,
          controller: _passwordController,
          obscureText: _obscurePassword,
          suffixWidget: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF8B9CB8),
              size: 18,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),

        const SizedBox(height: 4),

        // Password Requirements Hint
        // const Padding(
        //   padding: EdgeInsets.symmetric(horizontal: 4),
        //   child: Text(
        //     'Must be 8+ chars (e.g. Apna@123)',
        //     style: TextStyle(
        //       fontSize: 11,
        //       color: Color(0xFF64748B),
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        // ),

         const SizedBox(height: 12),

        // Primary Action Button ("Create Account")
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0066FF),
                Color(0xFF0052E0),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x600062FF),
                blurRadius: 18,
                offset: Offset(0, 6),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Color(0x250062FF),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? () {} : _handleSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // "Or register with" Divider
        Row(
          children: const [
            Expanded(
              child: Divider(color: Color(0xFFDEE7F5), thickness: 1.2),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Or register with',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8697B0),
                ),
              ),
            ),
            Expanded(
              child: Divider(color: Color(0xFFDEE7F5), thickness: 1.2),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Google Sign-In Button (Neumorphic Inset Style)
        InkWell(
          onTap: _isLoading ? null : _handleGoogleSignup,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FB),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFDEE7F5),
                width: 1.5,
              ),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x0A002870),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE5EEF9),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100038A8),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _buildGoogleColoredIcon(size: 19),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0052CC),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Already have an account? Sign In Link
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: widget.onSwitchToLogin ?? () => Navigator.maybePop(context),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0066FF),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        const Center(
          child: Text(
            'Powered by Sooftcode',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // Helper Widget for Input Field Cards (Neumorphic Pill with Left Icon Bevel Box)
  Widget _buildInputCard({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? prefixWidget,
    Widget? suffixWidget,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3E4D69),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FB),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFDEE7F5),
              width: 1.5,
            ),
            boxShadow: [
              const BoxShadow(
                color: Color(0x0C002870),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (prefixWidget != null)
                prefixWidget
              else
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFFE5EEF9),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100038A8),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: const Color(0xFF0066FF),
                      size: 18,
                    ),
                  ),
                ),
              Container(
                height: 18,
                width: 1.2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: const Color(0xFFD4E0F0),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  scrollPadding: const EdgeInsets.only(bottom: 90),
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF90A1B8),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              ?suffixWidget,
            ],
          ),
        ),
      ],
    );
  }

  // Helper Widget for Official Google Colored Logo
  Widget _buildGoogleColoredIcon({double size = 20}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

// Custom Painter for Authentic Multi-color Google "G" Logo
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Red Arc (Top)
    final pathRed = Path()
      ..moveTo(24.0, 9.5)
      ..cubicTo(29.05, 9.5, 33.15, 11.25, 36.15, 13.9)
      ..lineTo(42.9, 7.15)
      ..cubicTo(38.8, 3.35, 32.2, 1.0, 24.0, 1.0)
      ..cubicTo(14.7, 1.0, 6.7, 6.3, 2.7, 14.1)
      ..lineTo(10.5, 20.15)
      ..cubicTo(12.4, 13.9, 17.65, 9.5, 24.0, 9.5)
      ..close();
    canvas.drawPath(pathRed, Paint()..color = const Color(0xFFEA4335));

    // Yellow Arc (Left)
    final pathYellow = Path()
      ..moveTo(2.7, 14.1)
      ..cubicTo(1.0, 17.4, 0.0, 21.1, 0.0, 25.0)
      ..cubicTo(0.0, 28.9, 1.0, 32.6, 2.7, 35.9)
      ..lineTo(10.5, 29.85)
      ..cubicTo(9.85, 28.3, 9.5, 26.7, 9.5, 25.0)
      ..cubicTo(9.5, 23.3, 9.85, 21.7, 10.5, 20.15)
      ..lineTo(2.7, 14.1)
      ..close();
    canvas.drawPath(pathYellow, Paint()..color = const Color(0xFFFBBC05));

    // Green Arc (Bottom)
    final pathGreen = Path()
      ..moveTo(24.0, 40.5)
      ..cubicTo(17.65, 40.5, 12.4, 36.1, 10.5, 29.85)
      ..lineTo(2.7, 35.9)
      ..cubicTo(6.7, 43.7, 14.7, 49.0, 24.0, 49.0)
      ..cubicTo(32.8, 49.0, 39.8, 46.1, 44.8, 41.5)
      ..lineTo(37.3, 35.7)
      ..cubicTo(33.9, 38.9, 29.3, 40.5, 24.0, 40.5)
      ..close();
    canvas.drawPath(pathGreen, Paint()..color = const Color(0xFF34A853));

    // Blue Arc & Bar (Right)
    final pathBlue = Path()
      ..moveTo(48.0, 25.0)
      ..cubicTo(48.0, 23.3, 47.85, 21.7, 47.6, 20.1)
      ..lineTo(24.0, 20.1)
      ..lineTo(24.0, 29.8)
      ..lineTo(37.5, 29.8)
      ..cubicTo(36.9, 32.8, 35.1, 35.1, 32.4, 36.9)
      ..lineTo(40.2, 42.9)
      ..cubicTo(45.0, 38.5, 48.0, 32.2, 48.0, 25.0)
      ..close();
    canvas.drawPath(pathBlue, Paint()..color = const Color(0xFF4285F4));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Full Standalone SignupScreen with Matching Royal Navy Neumorphic Header & Curved White Sheet
class SignupScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;
  final String? initialPhone;

  const SignupScreen({
    super.key,
    this.initialEmail,
    this.initialPassword,
    this.initialPhone,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final fullHeaderHeight = (screenHeight * 0.28 - topPadding).clamp(130.0, 220.0);

    return Scaffold(
      backgroundColor: const Color(0xFF03102B),
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background Gradient (Deep Royal Navy)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF03102B),
                      Color(0xFF051C48),
                      Color(0xFF072663),
                    ],
                  ),
                ),
              ),
            ),

            // Main Layout
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top Header Text - Fixed Height (Does not collapse or slide upside on keyboard open)
                  SizedBox(
                    height: fullHeaderHeight,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "Create your new\nPOS account",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.18,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Join Apna POS to manage your restaurant effortlessly",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Rounded White Card Container (Anchored at fixed position)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x35001C60),
                            blurRadius: 30,
                            offset: Offset(0, -8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          18,
                          16,
                          18,
                          20 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Segmented Pill Tab Switcher (Login / Register)
                            Container(
                              height: 46,
                              padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF1FA),
                              borderRadius: BorderRadius.circular(23),
                              border: Border.all(
                                color: const Color(0xFFDFE8F6),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(19),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7C96),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(19),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x18002D80),
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                          spreadRadius: 1,
                                        ),
                                        BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 4,
                                          offset: Offset(0, -1),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0052CC),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          RegisterFormWidget(
                            initialEmail: widget.initialEmail,
                            initialPassword: widget.initialPassword,
                            initialPhone: widget.initialPhone,
                            onSwitchToLogin: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
