import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';

class LoyaltyRedemptionDialog extends StatefulWidget {
  final String customerPhone;
  final String customerName;
  final double currentOrderTotal;
  final void Function(double discountAmount, String stageId, int pointsToRedeem) onDiscountApplied;
  final LoyaltyService? loyaltyService;

  const LoyaltyRedemptionDialog({
    super.key,
    required this.customerPhone,
    this.customerName = '',
    required this.currentOrderTotal,
    required this.onDiscountApplied,
    this.loyaltyService,
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
  late final LoyaltyService _loyaltyService = widget.loyaltyService ?? LoyaltyService();
  static const Color _primaryGreen = Color(0xFF047857);

  bool _isLoading = true;
  String? _errorMessage;
  CustomerLoyaltyModel? _customerLoyalty;
  double _redeemAmount = 0.0;

  // OTP Step State
  bool _isOtpStep = false;
  double _customRedeemAmount = 0.0;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _customPointsController = TextEditingController();
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
    _customPointsController.dispose();
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
        final available = loyalty?.cashbackBalance ?? 0.0;
        final maxEligible = widget.currentOrderTotal > 0
            ? min(available, widget.currentOrderTotal)
            : available;
        setState(() {
          _customerLoyalty = loyalty;
          _isLoading = false;
          _redeemAmount = maxEligible > 0 ? maxEligible : 0.0;
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

  double get _maxRedeemable {
    final available = _customerLoyalty?.cashbackBalance ?? 0.0;
    if (widget.currentOrderTotal > 0) {
      return min(available, widget.currentOrderTotal);
    }
    return available;
  }

  String get _membershipTier {
    final visits = _customerLoyalty?.totalVisits ?? 0;
    if (visits >= 15) return 'Platinum Member';
    if (visits >= 5) return 'Gold Member';
    if (visits >= 1) return 'Silver Member';
    return 'Gold Member';
  }

  String _formatPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
    } else if (clean.length > 10 && clean.startsWith('91')) {
      final sub = clean.substring(2);
      if (sub.length == 10) {
        return '+91 ${sub.substring(0, 5)} ${sub.substring(5)}';
      }
    }
    return phone.isNotEmpty ? phone : '+91 98765 43210';
  }

  void _incrementRedeem() {
    final maxVal = _maxRedeemable;
    if (maxVal <= 0) return;
    setState(() {
      _redeemAmount = min(maxVal, _redeemAmount + 10.0);
    });
  }

  void _decrementRedeem() {
    if (_redeemAmount <= 0) return;
    setState(() {
      _redeemAmount = max(0.0, _redeemAmount - 10.0);
    });
  }

  void _showCustomAmountInputDialog() {
    final maxVal = _maxRedeemable;
    final controller = TextEditingController(text: _redeemAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Cashback to Redeem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: '0.00',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Maximum redeemable: ₹${maxVal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.trim()) ?? 0.0;
              setState(() {
                _redeemAmount = val.clamp(0.0, maxVal);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApplyCashback() async {
    final available = _customerLoyalty?.cashbackBalance ?? 0.0;
    if (_redeemAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an amount greater than ₹0 to redeem'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_redeemAmount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount exceeds available cashback (₹${available.toInt()})'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _customRedeemAmount = _redeemAmount;
      _otpError = null;
    });

    try {
      final res = await _loyaltyService.sendRedemptionOtp(
        phone: widget.customerPhone,
        stageId: 'cashback_custom',
        pointsToRedeem: _redeemAmount,
        amountToRedeem: _redeemAmount,
      );

      final rawMsg = res['message']?.toString().trim() ?? '';
      final safeMsg = (rawMsg.isEmpty || rawMsg.contains('OTP generated:'))
          ? 'OTP sent to customer mobile/WhatsApp'
          : rawMsg;

      if (mounted) {
        setState(() {
          _isSendingOtp = false;
          _isOtpStep = true;
        });
        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              safeMsg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: _primaryGreen,
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
        final discountAmount = (res['discountAmount'] as num?)?.toDouble() ?? _customRedeemAmount;
        final stageId = res['stageId']?.toString() ?? 'cashback_custom';
        final pointsToRedeem = (res['pointsToRedeem'] as num?)?.toInt() ?? _customRedeemAmount.toInt();

        widget.onDiscountApplied(discountAmount, stageId, pointsToRedeem);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 ₹${discountAmount.toStringAsFixed(2)} Cashback Discount Applied to Cart!',
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

  void _showHistorySheet(BuildContext context) {
    final loyalty = _customerLoyalty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Loyalty & Cashback History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildHistoryRow('Customer Phone', widget.customerPhone),
            _buildHistoryRow('Total Visits', '${loyalty?.totalVisits ?? 0} orders'),
            _buildHistoryRow('Lifetime Cashback Earned', '₹${(loyalty?.totalCashbackEarned ?? 0.0).toStringAsFixed(2)}'),
            _buildHistoryRow('Lifetime Cashback Redeemed', '₹${(loyalty?.totalCashbackRedeemed ?? 0.0).toStringAsFixed(2)}'),
            _buildHistoryRow('Current Available Cashback', '₹${(loyalty?.cashbackBalance ?? 0.0).toStringAsFixed(2)}', isBold: true),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(String title, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 13.5, color: isBold ? const Color(0xFF047857) : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: _primaryGreen, strokeWidth: 2.5),
                  ),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: _fetchCustomerLoyalty,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                _buildExactLoyaltyRedeemView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExactLoyaltyRedeemView() {
    final availableCashback = _customerLoyalty?.cashbackBalance ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Header Bar: Back button, Title & History button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Loyalty Redeem',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Get instant cashback on this bill',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // History Pill Button
            InkWell(
              onTap: () => _showHistorySheet(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.history_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 5),
                    Text(
                      'History',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 2. Available Cashback Card (Rich Emerald Gradient)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 14, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF025A36), Color(0xFF047857), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Wallet illustration
              _buildWalletIllustration(),

              // Center: Available Cashback Title & Amount
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Available Cashback',
                    style: TextStyle(
                      color: Color(0xFFD1FAE5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${availableCashback.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              // Right: Gift Box illustration
              _buildGiftBoxIllustration(),
            ],
          ),
        ),

        // 3. Customer Info Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerName.isNotEmpty
                          ? widget.customerName
                          : (_customerLoyalty?.customerName.isNotEmpty == true
                              ? _customerLoyalty!.customerName
                              : 'Customer'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPhone(widget.customerPhone),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      _membershipTier,
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 4. Section: Redeem Cashback Header
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Redeem Cashback',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Apply your available cashback to get instant discount on this bill.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        // 5. Cashback to Redeem Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12, bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Cashback to Redeem',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stepper Selector [ - ] ₹250.00 [ + ]
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _decrementRedeem,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.remove, size: 18, color: Color(0xFF334155)),
                      ),
                    ),
                    InkWell(
                      onTap: _showCustomAmountInputDialog,
                      child: Text(
                        '₹${_redeemAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _incrementRedeem,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 18, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Maximum redeemable: ₹${_maxRedeemable.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // "You Get" Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You Get',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '₹${_redeemAmount.toStringAsFixed(2)} Cashback',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF15803D),
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

        // 6. Bottom Action Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            onPressed: _isSendingOtp ? null : _handleApplyCashback,
            child: _isSendingOtp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Apply Cashback',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletIllustration() {
    return SizedBox(
      width: 58,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Cash bill 1 (Left tilt)
          Positioned(
            top: 2,
            left: 8,
            child: Transform.rotate(
              angle: -0.25,
              child: Container(
                width: 30,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white, width: 0.8),
                ),
                child: const Center(
                  child: Text('₹', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          // Cash bill 2 (Right tilt)
          Positioned(
            top: 4,
            right: 8,
            child: Transform.rotate(
              angle: 0.15,
              child: Container(
                width: 32,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white, width: 0.8),
                ),
                child: const Center(
                  child: Text('₹', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          // Leather Wallet Body
          Positioned(
            bottom: 0,
            child: Container(
              width: 48,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 4,
                    top: 10,
                    child: Container(
                      width: 14,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB45309),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(5),
                          bottomLeft: Radius.circular(5),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftBoxIllustration() {
    return SizedBox(
      width: 54,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Sparkle dots
          const Positioned(
            top: 2,
            right: 4,
            child: Text('✨', style: TextStyle(fontSize: 10)),
          ),
          const Positioned(
            left: 2,
            top: 12,
            child: Text('✨', style: TextStyle(fontSize: 8)),
          ),
          // Red Gift Box Body
          Positioned(
            bottom: 2,
            child: Container(
              width: 40,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF87171), Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Stack(
                children: [
                  // Vertical yellow ribbon
                  Center(
                    child: Container(width: 8, color: const Color(0xFFFACC15)),
                  ),
                  // Horizontal yellow ribbon
                  Center(
                    child: Container(height: 8, color: const Color(0xFFFACC15)),
                  ),
                ],
              ),
            ),
          ),
          // Yellow bow on top
          Positioned(
            top: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE047),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFCA8A04), width: 0.8),
                    ),
                  ),
                ),
                const SizedBox(width: 1),
                Transform.rotate(
                  angle: 0.35,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE047),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFCA8A04), width: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _isOtpStep = false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verify Authorization OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Redeem ₹${_customRedeemAmount.toStringAsFixed(2)} cashback',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2DD4BF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sms_outlined, color: _primaryGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A 4-digit verification OTP was sent to ${widget.customerPhone} on WhatsApp. Enter it to authorize this ₹${_customRedeemAmount.toStringAsFixed(2)} discount.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Enter 4-Digit OTP',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          autofocus: true,
          scrollPadding: const EdgeInsets.only(bottom: 90),
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
          ),
          textAlign: TextAlign.center,
          cursorColor: _primaryGreen,
          decoration: InputDecoration(
            counterText: '',
            errorText: _otpError,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryGreen, width: 2)),
          ),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              elevation: 1,
            ),
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
            child: _isVerifyingOtp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Verify OTP & Apply ₹${_customRedeemAmount.toStringAsFixed(2)} Discount',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: _resendCountdown == 0 ? _handleApplyCashback : null,
            child: Text(
              _resendCountdown > 0 ? 'Resend OTP in ${_resendCountdown}s' : 'Resend OTP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _resendCountdown == 0 ? _primaryGreen : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
