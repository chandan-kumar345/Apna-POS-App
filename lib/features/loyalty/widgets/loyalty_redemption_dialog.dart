import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';

class LoyaltyRedemptionDialog extends StatefulWidget {
  final String customerPhone;
  final String customerName;
  final double currentOrderTotal;
  final void Function(double discountAmount, String stageId, int pointsToRedeem) onDiscountApplied;

  const LoyaltyRedemptionDialog({
    super.key,
    required this.customerPhone,
    this.customerName = '',
    required this.currentOrderTotal,
    required this.onDiscountApplied,
  });

  static Future<void> show(
    BuildContext context, {
    required String customerPhone,
    String customerName = '',
    required double currentOrderTotal,
    required void Function(double discountAmount, String stageId, int pointsToRedeem) onDiscountApplied,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoyaltyRedemptionDialog(
        customerPhone: customerPhone,
        customerName: customerName,
        currentOrderTotal: currentOrderTotal,
        onDiscountApplied: onDiscountApplied,
      ),
    );
  }

  @override
  State<LoyaltyRedemptionDialog> createState() => _LoyaltyRedemptionDialogState();
}

class _LoyaltyRedemptionDialogState extends State<LoyaltyRedemptionDialog> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  static const Color _primaryNavy = Color(0xFF082559);

  bool _isLoading = true;
  String? _errorMessage;
  CustomerLoyaltyModel? _customerLoyalty;

  // OTP Step State
  bool _isOtpStep = false;
  AvailableRewardStageModel? _selectedStage;
  final TextEditingController _otpController = TextEditingController();
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  String? _otpError;
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchCustomerLoyalty();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _resendCountdown = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  Future<void> _fetchCustomerLoyalty() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loyalty = await _loyaltyService.getCustomerLoyalty(
        widget.customerPhone,
        name: widget.customerName,
      );

      if (mounted) {
        setState(() {
          _customerLoyalty = loyalty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load loyalty balance: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSendOtp(AvailableRewardStageModel stage) async {
    setState(() {
      _isSendingOtp = true;
      _selectedStage = stage;
      _otpError = null;
    });

    try {
      final res = await _loyaltyService.sendRedemptionOtp(
        phone: widget.customerPhone,
        stageId: stage.id,
      );

      if (mounted) {
        setState(() {
          _isSendingOtp = false;
          _isOtpStep = true;
        });
        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? 'OTP sent to customer mobile',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: _primaryNavy,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e', style: const TextStyle(color: Colors.white, fontSize: 12)),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _otpError = 'Please enter valid 4-digit OTP');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _otpError = null;
    });

    try {
      final res = await _loyaltyService.verifyRedemptionOtp(
        phone: widget.customerPhone,
        otp: otp,
      );

      if (mounted) {
        final discountAmount = (res['discountAmount'] as num?)?.toDouble() ?? _selectedStage!.rewardValue;
        final stageId = res['stageId']?.toString() ?? _selectedStage!.id;
        final pointsToRedeem = (res['pointsToRedeem'] as num?)?.toInt() ?? _selectedStage!.requiredPoints;

        widget.onDiscountApplied(discountAmount, stageId, pointsToRedeem);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 ₹${discountAmount.toInt()} Loyalty Discount Applied to Cart!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          _otpError = 'Invalid or expired OTP. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primaryNavy.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.card_giftcard_rounded, color: _primaryNavy, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Customer Loyalty Rewards',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: CircularProgressIndicator(color: _primaryNavy, strokeWidth: 2.5),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchCustomerLoyalty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isOtpStep)
              _buildOtpVerificationView()
            else
              _buildStagesListView(),
          ],
        ),
      ),
    );
  }

  Widget _buildStagesListView() {
    final balance = _customerLoyalty?.pointsBalance ?? 0;
    final pointsName = _customerLoyalty?.pointsName ?? 'Cookie';
    final visits = _customerLoyalty?.totalVisits ?? 0;
    final stages = _customerLoyalty?.availableStages ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF082559), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primaryNavy.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName.isNotEmpty ? widget.customerName : widget.customerPhone,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Phone: ${widget.customerPhone} • $visits Visits',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cookie_outlined, color: Color(0xFFFDE68A), size: 16),
                    const SizedBox(width: 5),
                    Text(
                      '$balance $pointsName',
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'Unlocked Loyalty Stage Rewards',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),

        if (stages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No loyalty stages configured yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ...stages.map((stage) {
            final isUnlocked = stage.isUnlocked;
            final isMinSpendMet = widget.currentOrderTotal >= stage.minimumPurchase;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnlocked ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUnlocked ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                  width: isUnlocked ? 1.2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isUnlocked ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUnlocked ? Icons.card_giftcard_rounded : Icons.lock_outline_rounded,
                      color: isUnlocked ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${stage.requiredPoints} $pointsName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isUnlocked ? const Color(0xFF16A34A) : const Color(0xFF475569),
                              ),
                            ),
                            if (isUnlocked) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'UNLOCKED',
                                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 8.5, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stage.freeItemName,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Min. Purchase: ₹${stage.minimumPurchase.toInt()}',
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  if (isUnlocked)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: (_isSendingOtp || !isMinSpendMet) ? null : () => _handleSendOtp(stage),
                      child: _isSendingOtp && _selectedStage?.id == stage.id
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isMinSpendMet ? 'Redeem (OTP)' : 'Min ₹${stage.minimumPurchase.toInt()}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                    )
                  else
                    Text(
                      'Need ${stage.requiredPoints - balance} more',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildOtpVerificationView() {
    final stage = _selectedStage;
    if (stage == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20, color: _primaryNavy),
              onPressed: () => setState(() => _isOtpStep = false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Text(
              'Redeem ₹${stage.rewardValue.toInt()} Discount',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2DD4BF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sms_outlined, color: _primaryNavy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A 4-digit OTP from "APNA POS" was sent to customer ${widget.customerPhone}. Enter it below to authorize this ₹${stage.rewardValue.toInt()} discount.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        const Text('Enter 4-Digit OTP', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
          textAlign: TextAlign.center,
          cursorColor: _primaryNavy,
          decoration: InputDecoration(
            counterText: '',
            errorText: _otpError,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.8)),
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 11),
              elevation: 0,
            ),
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
            child: _isVerifyingOtp
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Verify OTP & Apply ₹${stage.rewardValue.toInt()} Discount',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 10),

        Center(
          child: TextButton(
            onPressed: _resendCountdown == 0 ? () => _handleSendOtp(stage) : null,
            child: Text(
              _resendCountdown > 0 ? 'Resend OTP in ${_resendCountdown}s' : 'Resend OTP',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: _resendCountdown == 0 ? _primaryNavy : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
