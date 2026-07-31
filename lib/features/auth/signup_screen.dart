import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import 'login_screen.dart';
import 'create_profile_screen.dart';

// Standalone Register Form Widget (Embedded inline inside LoginScreen or used standalone)
class RegisterFormWidget extends StatefulWidget {
  const RegisterFormWidget({super.key});

  @override
  State<RegisterFormWidget> createState() => _RegisterFormWidgetState();
}

class _RegisterFormWidgetState extends State<RegisterFormWidget> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  final db = DatabaseService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Trigger OTP Verification Popup when clicking "Continue"
  Future<void> _handleSignup() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final emailText = _emailController.text.trim();
    _showOtpVerificationDialog(emailText);
  }

  // OTP Verification Popup Dialog with Theme Colors, Resend OTP, and Verify Button
  void _showOtpVerificationDialog(String emailText) {
    final otp1 = TextEditingController(text: '1');
    final otp2 = TextEditingController(text: '2');
    final otp3 = TextEditingController(text: '3');
    final otp4 = TextEditingController(text: '4');
    String? otpError;
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 25,
                      offset: Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF00C2FF), // Theme Cyan Highlight Border
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Header
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0052FF).withOpacity(0.1),
                        border: Border.all(color: const Color(0xFF00C2FF), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mark_email_read_rounded,
                          color: GlassTheme.primaryBlue,
                          size: 30,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Popup Title
                    const Text(
                      'OTP Verification',
                      style: TextStyle(
                        fontSize: 20,
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

                    const SizedBox(height: 20),

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

                    // 4 Semi-Circle / Pill OTP Input Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildOtpPillBox(otp1, autoFocus: true),
                        _buildOtpPillBox(otp2),
                        _buildOtpPillBox(otp3),
                        _buildOtpPillBox(otp4),
                      ],
                    ),

                    const SizedBox(height: 20),

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
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GlassTheme.primaryNavy,
                                content: Text(
                                  'OTP verification code resent to $emailText',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
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
                              color: Color(0xFF00C2FF),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Verify Button (Theme Gradient Pill Button)
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: GlassTheme.primaryButtonGradient,
                        boxShadow: [
                          BoxShadow(
                            color: GlassTheme.primaryBlue.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isVerifying
                            ? null
                            : () async {
                                final enteredOtp =
                                    '${otp1.text}${otp2.text}${otp3.text}${otp4.text}'.trim();
                                if (enteredOtp.length < 4) {
                                  setDialogState(() {
                                    otpError = 'Please enter complete 4-digit OTP';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isVerifying = true;
                                  otpError = null;
                                });

                                // Register user in database
                                final nameFromEmail = emailText.contains('@')
                                    ? emailText.split('@').first
                                    : emailText;
                                final success = await db.registerUser(
                                  name: nameFromEmail.isNotEmpty
                                      ? nameFromEmail
                                      : 'Restaurant Owner',
                                  email: emailText,
                                  password: _passwordController.text.trim(),
                                  pin: '1234',
                                );

                                if (!mounted) return;

                                if (success) {
                                  Navigator.pop(context); // Close OTP Dialog
                                  Navigator.pushReplacement(
                                    context,
                                    SlideRightPageRoute(
                                      page: CreateProfileScreen(
                                        initialEmail: emailText,
                                        initialName: nameFromEmail,
                                      ),
                                    ),
                                  );
                                } else {
                                  setDialogState(() {
                                    isVerifying = false;
                                    otpError =
                                        'Registration failed. Email may already be registered.';
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
            );
          },
        );
      },
    );
  }

  // Helper Widget for OTP Pill Box Input
  Widget _buildOtpPillBox(TextEditingController controller, {bool autoFocus = false}) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C2FF), // Theme Cyan Highlight Border
          width: 1.5,
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          autofocus: autoFocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              FocusScope.of(context).nextFocus();
            }
          },
        ),
      ),
    );
  }

  void _showGoogleAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGoogleColoredIcon(size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Sign up with Google',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose an account to continue to Apna POS',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF3B82F6),
                  child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('Admin Owner', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('owner@apnapos.com', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(context);
                  _emailController.text = 'owner@apnapos.com';
                  _passwordController.text = '123456';
                  _handleSignup();
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF10B981),
                  child: Text('C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('Chandan Yaduvanshi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('chandan@apnapos.com', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(context);
                  _emailController.text = 'chandan@apnapos.com';
                  _passwordController.text = '123456';
                  _handleSignup();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error Banner
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
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
          const SizedBox(height: 12),
        ],

        // Form Input Fields (Email Address & Password)
        _buildInputCard(
          label: 'Email Address',
          hint: 'Enter email address',
          icon: Icons.mail_outline_rounded,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 12),

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
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),

        const SizedBox(height: 20),

        // Primary Action Button ("Continue")
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: GlassTheme.primaryButtonGradient,
            boxShadow: [
              BoxShadow(
                color: GlassTheme.primaryBlue.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // "Or register with" Divider
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Or register with',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
          ],
        ),

        const SizedBox(height: 14),

        // Google Signup Button with Official Google G Logo
        OutlinedButton(
          onPressed: _showGoogleAccountPicker,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGoogleColoredIcon(size: 20),
              const SizedBox(width: 8),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper Widget for Input Field Cards (Semi-Circle Pill Shape)
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
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26), // Semi-circle pill shape
            border: Border.all(
              color: const Color(0xFF00C2FF), // Highlighted Cyan border
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1400C2FF),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: GlassTheme.primaryBlue, size: 20),
              const SizedBox(width: 10),
              if (prefixWidget != null) prefixWidget,
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFCBD5E1),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffixWidget != null) suffixWidget,
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
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

// Backward compatibility alias for SignupScreen
typedef SignupScreen = RegisterFormWidget;
