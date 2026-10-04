import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/email_service.dart';
import '../../core/widgets/otp_pin_input.dart';

/// Standalone & Reusable Neumorphic OTP Verification Screen
/// Supports both full-screen navigation and modal dialog wrapping with zero overflow.
class OtpVerificationScreen extends StatefulWidget {
  final String? email;
  final String? phone;
  final String? senderEmail;
  final int length;
  final Future<bool> Function(String otp)? onVerify;
  final Future<void> Function()? onResend;
  final VoidCallback? onSuccess;
  final bool isModal;

  const OtpVerificationScreen({
    super.key,
    this.email,
    this.phone,
    this.senderEmail,
    this.length = 4,
    this.onVerify,
    this.onResend,
    this.onSuccess,
    this.isModal = false,
  });

  /// Helper to show OTP Verification as a responsive centered modal popup
  static Future<bool?> showAsDialog({
    required BuildContext context,
    String? email,
    String? phone,
    String? senderEmail,
    int length = 4,
    Future<bool> Function(String otp)? onVerify,
    Future<void> Function()? onResend,
    VoidCallback? onSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: OtpVerificationScreen(
          email: email,
          phone: phone,
          senderEmail: senderEmail,
          length: length,
          onVerify: onVerify,
          onResend: onResend,
          onSuccess: onSuccess,
          isModal: true,
        ),
      ),
    );
  }

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  String get _recipientDisplay {
    if (widget.email != null && widget.email!.isNotEmpty) {
      return widget.email!;
    }
    if (widget.phone != null && widget.phone!.isNotEmpty) {
      return widget.phone!;
    }
    return 'your registered account';
  }

  String get _senderDisplay => widget.senderEmail ?? EmailService.senderEmail;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _handleResend() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _otpController.clear();
    });

    try {
      if (widget.onResend != null) {
        await widget.onResend!();
      } else if (widget.email != null && widget.email!.isNotEmpty) {
        await EmailService().sendOtpEmail(widget.email!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            content: Text(
              'New verification code resent to $_recipientDisplay',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      _startResendTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleVerify() async {
    final enteredCode = _otpController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (enteredCode.length < widget.length) {
      setState(() {
        _errorMessage = 'Please enter the complete ${widget.length}-digit OTP code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      bool isValid = false;
      if (widget.onVerify != null) {
        isValid = await widget.onVerify!(enteredCode);
      } else if (widget.email != null && widget.email!.isNotEmpty) {
        isValid = EmailService().verifyOtp(widget.email!, enteredCode);
      } else {
        isValid = true;
      }

      if (!isValid) {
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _errorMessage = 'Invalid or expired OTP code. Please try again.';
          });
        }
        return;
      }

      if (mounted) {
        widget.onSuccess?.call();
        if (widget.isModal) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Widget _buildCardContent() {
    final isPhone = widget.phone != null && widget.phone!.isNotEmpty;

    return Stack(
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
              // // Dual Halo Icon Badge
              // Container(
              //   width: 76,
              //   height: 76,
              //   decoration: const BoxDecoration(
              //     shape: BoxShape.circle,
              //     color: Color(0xFFEBF3FF),
              //   ),
              //   child: Center(
              //     child: Container(
              //       width: 56,
              //       height: 56,
              //       decoration: const BoxDecoration(
              //         shape: BoxShape.circle,
              //         color: Color(0xFFD6E6FF),
              //       ),
              //       child: Center(
              //         child: Stack(
              //           clipBehavior: Clip.none,
              //           children: [
              //             Icon(
              //               isPhone ? Icons.phone_iphone_rounded : Icons.mail_rounded,
              //               color: const Color(0xFF0066FF),
              //               size: 28,
              //             ),
              //             Positioned(
              //               right: -2,
              //               bottom: -2,
              //               child: Container(
              //                 padding: const EdgeInsets.all(2),
              //                 decoration: const BoxDecoration(
              //                   color: Color(0xFF0066FF),
              //                   shape: BoxShape.circle,
              //                 ),
              //                 child: const Icon(
              //                   Icons.check_rounded,
              //                   color: Colors.white,
              //                   size: 10,
              //                 ),
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),

              const SizedBox(height: 18),

              // Title
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

              // Subtitle
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'Enter the ${widget.length}-digit verification code sent to\n',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: _recipientDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (!isPhone) ...[
                      const TextSpan(
                        text: '\nby ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      TextSpan(
                        text: _senderDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0066FF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Error Message
              if (_errorMessage != null) ...[
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

              // 4 Neumorphic Rounded PIN Boxes
              OtpPinInput(
                controller: _otpController,
                focusNode: _otpFocusNode,
                length: widget.length,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                onSubmitted: (_) => _handleVerify(),
              ),

              const SizedBox(height: 18),

              // Resend Row
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
                    onPressed: (_resendCountdown > 0 || _isResending) ? null : _handleResend,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend OTP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _resendCountdown > 0 ? const Color(0xFF94A3B8) : const Color(0xFF0066FF),
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
                  onPressed: _isVerifying ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: _isVerifying
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

        // Close Button
        Positioned(
          top: 14,
          right: 14,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(false),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal) {
      return Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _buildCardContent(),
          ),
        ),
      );
    }

    // Full-Screen Scaffold Presentation
    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF021B54),
                    Color(0xFF03318C),
                    Color(0xFF011848),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildCardContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
