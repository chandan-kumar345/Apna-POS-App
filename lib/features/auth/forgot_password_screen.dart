import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/email_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/form_validators.dart';

/// Helper function to display the Forgot Password dialog as a responsive popup modal
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String? initialEmail,
  ValueChanged<String>? onPasswordResetSuccess,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ForgotPasswordDialog(
      initialEmail: initialEmail,
      onPasswordResetSuccess: onPasswordResetSuccess,
    ),
  );
}

/// Responsive Modal Dialog for Forgot Password
class ForgotPasswordDialog extends StatefulWidget {
  final String? initialEmail;
  final ValueChanged<String>? onPasswordResetSuccess;

  const ForgotPasswordDialog({
    super.key,
    this.initialEmail,
    this.onPasswordResetSuccess,
  });

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _otpFocus = FocusNode();
  final FocusNode _newPasswordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _errorMessage;
  String? _successMessage;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _otpFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 45;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCountdown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCountdown--;
          });
        }
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailErr = FormValidators.validateEmail(email);
    if (emailErr != null) {
      setState(() {
        _errorMessage = emailErr;
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await EmailService().sendOtpEmail(email);
      if (!mounted) return;

      setState(() {
        _isSendingOtp = false;
        _otpSent = true;
        _successMessage = 'OTP code sent to $email';
      });
      _startResendTimer();
      _otpFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _handleResetPassword() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. Email validation
    final emailErr = FormValidators.validateEmail(email);
    if (emailErr != null) {
      setState(() => _errorMessage = emailErr);
      return;
    }

    // 2. OTP validation
    if (otp.length < 4) {
      setState(() => _errorMessage = 'Please enter the complete 4-digit OTP code.');
      return;
    }

    // 3. Verify OTP code
    final isOtpValid = EmailService().verifyOtp(email, otp);
    if (!isOtpValid) {
      setState(() => _errorMessage = 'Invalid or expired OTP code. Please check your email or click Resend.');
      return;
    }

    // 4. Password validation
    final passErr = FormValidators.validatePassword(newPassword);
    if (passErr != null) {
      setState(() => _errorMessage = passErr);
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match. Please re-enter confirm password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call backend reset password API
      await AuthService().resetPassword(email, newPassword);

      // Clear OTP cache
      EmailService().clearOtp(email);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _successMessage = 'Password updated successfully!';
      });

      // Notify caller
      widget.onPasswordResetSuccess?.call(email);

      // Dismiss dialog
      Navigator.pop(context);
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception:', '').trim();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = errStr;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row (Icon + Title + Close Button)
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFF0066FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Enter your email to verify and reset',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Error Message Banner
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
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
                ],

                // Success Message Banner
                if (_successMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1. Registered Email Field
                const Text(
                  'Registered Email Address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'name@domain.com',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSendingOtp || _resendCountdown > 0 ? null : _handleSendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _resendCountdown > 0
                                    ? '${_resendCountdown}s'
                                    : (_otpSent ? 'Resend' : 'Send OTP'),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 2. 4-Digit OTP Code
                const Text(
                  '4-Digit OTP Code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _otpController,
                  focusNode: _otpFocus,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '1234',
                    hintStyle: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 14,
                      letterSpacing: 4,
                    ),
                    prefixIcon: const Icon(Icons.pin_outlined, size: 18, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. New Password
                const Text(
                  'New Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _newPasswordController,
                  focusNode: _newPasswordFocus,
                  obscureText: _obscureNewPassword,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Enter new password (min. 6 chars)',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Confirm Password
                const Text(
                  'Confirm New Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocus,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Re-enter new password',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 5. Submit / Reset Password Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Back to Sign In Link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel & Back to Sign In',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
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
  }
}

/// Standalone Full-Screen Forgot Password Page (responsive across all screen sizes)
class ForgotPasswordScreen extends StatelessWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ForgotPasswordDialog(
            initialEmail: initialEmail,
            onPasswordResetSuccess: (email) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password updated successfully! Please sign in.'),
                  backgroundColor: Color(0xFF051C48),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
