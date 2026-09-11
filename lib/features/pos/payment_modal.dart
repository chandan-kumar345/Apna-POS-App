import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/order_model.dart';
import '../../core/database/database_service.dart';
import '../../core/services/payment_service.dart';

class PaymentModalResult {
  final String paymentMethod;
  final double roundOff;
  final double totalAmount;
  final double? cashTendered;

  PaymentModalResult({
    required this.paymentMethod,
    required this.roundOff,
    required this.totalAmount,
    this.cashTendered,
  });
}

class PaymentModal extends StatefulWidget {
  final OrderModel order;
  final String currency;

  const PaymentModal({
    super.key,
    required this.order,
    required this.currency,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _selectedMethod = 'Cash'; // Default: Cash option visible first
  bool _isUpiPaymentConfirmed = false;
  bool _isSubmitting = false; // Lock to prevent duplicate submissions
  String? _upiTransactionRef;
  Timer? _upiPollingTimer;

  // Dynamic QR & Verification State
  bool _isGeneratingQr = false;
  PaymentQrResult? _dynamicQrResult;
  int _upiExpirySeconds = 300; // 5 minutes countdown
  Timer? _expiryCountdownTimer;

  // Cash controller
  final _cashTenderedController = TextEditingController();

  // Split controllers
  final _splitCashCtrl = TextEditingController();
  final _splitCardCtrl = TextEditingController();
  final _splitUpiCtrl = TextEditingController();

  // Card sub-type
  String _selectedCardType = 'Visa / Mastercard';

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final double rawTotal = widget.order.totalAmount;
    final double roundedTotal = rawTotal.roundToDouble();
    _cashTenderedController.text = roundedTotal.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _stopUpiPolling();
    _stopExpiryCountdown();
    _cashTenderedController.dispose();
    _splitCashCtrl.dispose();
    _splitCardCtrl.dispose();
    _splitUpiCtrl.dispose();
    super.dispose();
  }

  void _startExpiryCountdown() {
    _stopExpiryCountdown();
    _upiExpirySeconds = 300;
    _expiryCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_upiExpirySeconds > 0) {
        setState(() {
          _upiExpirySeconds--;
        });
      } else {
        _stopExpiryCountdown();
      }
    });
  }

  void _stopExpiryCountdown() {
    _expiryCountdownTimer?.cancel();
    _expiryCountdownTimer = null;
  }

  Future<void> _fetchDynamicUpiQr(double roundedTotal) async {
    if (!mounted) return;
    setState(() {
      _isGeneratingQr = true;
    });

    try {
      final db = DatabaseService();
      final orderNumber = widget.order.orderNumber.isNotEmpty
          ? widget.order.orderNumber
          : (widget.order.id.length > 8
              ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase()
              : widget.order.id);

      final qrResult = await db.generateUpiPaymentQr(
        orderId: widget.order.id,
        orderNumber: orderNumber,
        amount: roundedTotal,
        customerName: widget.order.customerName,
        customerPhone: widget.order.customerPhone,
      );

      if (mounted) {
        setState(() {
          _dynamicQrResult = qrResult;
          _isGeneratingQr = false;
        });
        _startExpiryCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingQr = false;
        });
      }
    }
  }

  void _startUpiPolling(double roundedTotal, double roundOff) {
    _stopUpiPolling();

    // If dynamic QR not yet generated, request it
    if (_dynamicQrResult == null && !_isGeneratingQr) {
      _fetchDynamicUpiQr(roundedTotal);
    }

    _upiPollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) async {
      if (!mounted || _selectedMethod != 'UPI' || _isUpiPaymentConfirmed) return;
      final db = DatabaseService();
      final statusResult = await db.checkUpiPaymentStatusDetails(widget.order.id);
      if (statusResult.isPaid && mounted && !_isUpiPaymentConfirmed) {
        _onUpiPaymentAutoVerified(
          roundedTotal,
          roundOff,
          utr: statusResult.utr,
          paymentId: statusResult.paymentId,
        );
      }
    });
  }

  void _stopUpiPolling() {
    _upiPollingTimer?.cancel();
    _upiPollingTimer = null;
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _onUpiPaymentAutoVerified(
    double roundedAmount,
    double roundOff, {
    String? utr,
    String? paymentId,
  }) async {
    if (_isUpiPaymentConfirmed || _isSubmitting) return;
    _isSubmitting = true;
    _stopUpiPolling();
    _stopExpiryCountdown();

    HapticFeedback.heavyImpact();

    final String finalRef = utr ?? paymentId ?? 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    setState(() {
      _isUpiPaymentConfirmed = true;
      _upiTransactionRef = finalRef;
    });

    final nav = Navigator.of(context);
    final String finalMethod = 'UPI (UTR: $_upiTransactionRef)';
    nav.pop(PaymentModalResult(
      paymentMethod: finalMethod,
      roundOff: roundOff,
      totalAmount: roundedAmount,
    ));
  }

  void _validateAndSubmitPayment(
    BuildContext context,
    double payableAmount,
    double roundOff,
  ) async {
    if (_isSubmitting) return;
    _clearError();
    final String rawCashText = _cashTenderedController.text.trim();
    final double? parsedCash = double.tryParse(rawCashText);
    final double cashTendered = parsedCash ?? 0.0;

    final String rawSplitCash = _splitCashCtrl.text.trim();
    final String rawSplitCard = _splitCardCtrl.text.trim();
    final String rawSplitUpi = _splitUpiCtrl.text.trim();
    final double splitCash = double.tryParse(rawSplitCash) ?? 0.0;
    final double splitCard = double.tryParse(rawSplitCard) ?? 0.0;
    final double splitUpi = double.tryParse(rawSplitUpi) ?? 0.0;
    final double splitTotal = splitCash + splitCard + splitUpi;

    void showError(String msg) {
      setState(() {
        _errorMessage = msg;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    // 1. Cash Mode Validation
    if (_selectedMethod == 'Cash') {
      if (rawCashText.isEmpty) {
        showError('Please enter cash amount before confirming payment.');
        return;
      }
      if (parsedCash == null || cashTendered <= 0) {
        showError('Please enter a valid cash amount.');
        return;
      }
      if (cashTendered < payableAmount) {
        final double shortAmount = payableAmount - cashTendered;
        showError('Tendered cash is ${widget.currency}${shortAmount.toStringAsFixed(1)} short.');
        return;
      }
    }

    // 2. Split Mode Validation
    if (_selectedMethod == 'Split') {
      if (rawSplitCash.isEmpty && rawSplitCard.isEmpty && rawSplitUpi.isEmpty) {
        showError('Please enter split payment amounts.');
        return;
      }
      if (splitTotal <= 0) {
        showError('Please enter a valid split amount.');
        return;
      }
      if (splitTotal < payableAmount) {
        final double shortAmount = payableAmount - splitTotal;
        showError('Entered split total is ${widget.currency}${shortAmount.toStringAsFixed(1)} short.');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    String finalMethod = _selectedMethod;
    if (_selectedMethod == 'Cash') {
      finalMethod = 'Cash (Rec: ${widget.currency}${cashTendered.toStringAsFixed(0)})';
    } else if (_selectedMethod == 'Card') {
      finalMethod = 'Card ($_selectedCardType)';
    } else if (_selectedMethod == 'Split') {
      finalMethod =
          'Split (Cash: ${widget.currency}${splitCash.toStringAsFixed(0)}, Card: ${widget.currency}${splitCard.toStringAsFixed(0)}, UPI: ${widget.currency}${splitUpi.toStringAsFixed(0)})';
    }

    Navigator.of(context).pop(PaymentModalResult(
      paymentMethod: finalMethod,
      roundOff: (_selectedMethod == 'Cash' || _selectedMethod == 'UPI') ? roundOff : 0.0,
      totalAmount: payableAmount,
      cashTendered: _selectedMethod == 'Cash' ? cashTendered : null,
    ));
  }

  String _getOrderTypeLabel() {
    switch (widget.order.orderType) {
      case OrderType.delivery:
        return 'Delivery';
      case OrderType.takeaway:
        return 'Takeaway';
      case OrderType.dineIn:
        if (widget.order.tableNumber != null && widget.order.tableNumber!.trim().isNotEmpty) {
          final tNum = widget.order.tableNumber!.replaceAll('T-', '').trim();
          return 'Dine-In • Table $tNum';
        }
        return 'Dine-In';
    }
  }

  IconData _getOrderTypeIcon() {
    switch (widget.order.orderType) {
      case OrderType.delivery:
        return Icons.delivery_dining_rounded;
      case OrderType.takeaway:
        return Icons.shopping_bag_outlined;
      case OrderType.dineIn:
        return Icons.table_restaurant_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double rawTotal = widget.order.totalAmount;
    final double roundedTotal = rawTotal.roundToDouble();
    final double roundOff = roundedTotal - rawTotal;
    final bool isRoundOffApplicable = (_selectedMethod == 'Cash' || _selectedMethod == 'UPI');
    final double payableAmount = isRoundOffApplicable ? roundedTotal : rawTotal;

    final double cashTendered = double.tryParse(_cashTenderedController.text) ?? payableAmount;
    final double changeAmount = (cashTendered - payableAmount).clamp(0.0, 999999.0);
    final bool isCashDeficit = cashTendered < payableAmount;

    final double splitCash = double.tryParse(_splitCashCtrl.text) ?? 0.0;
    final double splitCard = double.tryParse(_splitCardCtrl.text) ?? 0.0;
    final double splitUpi = double.tryParse(_splitUpiCtrl.text) ?? 0.0;
    final double splitTotal = splitCash + splitCard + splitUpi;
    final double splitRemaining = payableAmount - splitTotal;

    final String orderNumDisplay = widget.order.orderNumber.isNotEmpty
        ? widget.order.orderNumber
        : (widget.order.id.length > 8
            ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase()
            : widget.order.id);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. FULL-SCREEN FROSTED GLASS BACKDROP BLUR
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _stopUpiPolling();
              _stopExpiryCountdown();
              Navigator.pop(context, null);
            },
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),

        // 2. COMPACT & ELEGANT PAYMENT MODAL
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. HEADER ROW (Icon, Title, Table Badge, Close)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Rounded POS Icon Container
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFDBEAFE), width: 1.0),
                                  ),
                                  child: const Icon(
                                    Icons.point_of_sale_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Title, Pill Badge, and Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 2,
                                        children: [
                                          const Text(
                                            'Payment Checkout',
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFBBF7D0), width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(_getOrderTypeIcon(), size: 11, color: const Color(0xFF16A34A)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _getOrderTypeLabel(),
                                                  style: const TextStyle(
                                                    color: Color(0xFF166534),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Order #$orderNumDisplay • ${widget.order.items.length} ${widget.order.items.length == 1 ? "item" : "items"}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Close Button
                                InkWell(
                                  onTap: () {
                                    _stopUpiPolling();
                                    _stopExpiryCountdown();
                                    Navigator.pop(context, null);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Color(0xFF475569), size: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 2. TOTAL PAYABLE BANNER (Light Pastel Blue Container matching UI screenshot)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F6FD),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2EDF9), width: 1.0),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left side: Header + Breakdown details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'TOTAL PAYABLE',
                                          style: TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 5,
                                          runSpacing: 2,
                                          children: [
                                            Text(
                                              'Sub: ${widget.currency}${widget.order.subtotal.toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (widget.order.discountAmount > 0) ...[
                                              const Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                                              Text(
                                                'Disc: -${widget.currency}${widget.order.discountAmount.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                  color: Color(0xFF16A34A),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                            if (widget.order.taxAmount > 0) ...[
                                              const Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                                              Text(
                                                'Tax: ${widget.currency}${widget.order.taxAmount.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                            if (isRoundOffApplicable && roundOff != 0.0) ...[
                                              const Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                                              Text(
                                                'Rnd: ${roundOff >= 0 ? "+" : ""}${widget.currency}${roundOff.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: Color(0xFFD97706),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Vertical separator line
                                  Container(
                                    height: 38,
                                    width: 1.2,
                                    color: const Color(0xFFD0E1F9),
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  // Right side: Main Amount & Exact Subtitle
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${widget.currency} ${payableAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF0044CC),
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        'Exact: ${widget.currency}${rawTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 3. PAYMENT METHOD TABS (4 Pastel Squircle Cards)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPastelMethodCard(
                                    method: 'Cash',
                                    icon: Icons.payments_rounded,
                                    bgColor: const Color(0xFFEFF6FF),
                                    iconBgColor: const Color(0xFFDBEAFE),
                                    activeBorderColor: const Color(0xFF2563EB),
                                    inactiveBorderColor: const Color(0xFFDBEAFE),
                                    iconColor: const Color(0xFF1D4ED8),
                                    textColor: const Color(0xFF1D4ED8),
                                    roundedTotal: roundedTotal,
                                    roundOff: roundOff,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPastelMethodCard(
                                    method: 'UPI',
                                    icon: Icons.qr_code_2_rounded,
                                    bgColor: const Color(0xFFFAF5FF),
                                    iconBgColor: const Color(0xFFF3E8FF),
                                    activeBorderColor: const Color(0xFF9333EA),
                                    inactiveBorderColor: const Color(0xFFF3E8FF),
                                    iconColor: const Color(0xFF9333EA),
                                    textColor: const Color(0xFF6B21A8),
                                    roundedTotal: roundedTotal,
                                    roundOff: roundOff,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPastelMethodCard(
                                    method: 'Card',
                                    icon: Icons.credit_card_rounded,
                                    bgColor: const Color(0xFFECFDF5),
                                    iconBgColor: const Color(0xFFD1FAE5),
                                    activeBorderColor: const Color(0xFF059669),
                                    inactiveBorderColor: const Color(0xFFD1FAE5),
                                    iconColor: const Color(0xFF059669),
                                    textColor: const Color(0xFF065F46),
                                    roundedTotal: roundedTotal,
                                    roundOff: roundOff,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPastelMethodCard(
                                    method: 'Split',
                                    icon: Icons.share_rounded,
                                    bgColor: const Color(0xFFFFF7ED),
                                    iconBgColor: const Color(0xFFFFEDD5),
                                    activeBorderColor: const Color(0xFFEA580C),
                                    inactiveBorderColor: const Color(0xFFFFEDD5),
                                    iconColor: const Color(0xFFEA580C),
                                    textColor: const Color(0xFF7C2D12),
                                    roundedTotal: roundedTotal,
                                    roundOff: roundOff,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Error alert banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFF991B1B),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // 4. DYNAMIC METHOD DETAILS CARD
                            if (_selectedMethod == 'Cash') ...[
                              // CASH RECEIVED CONTAINER
                              Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.payments_rounded, color: Color(0xFF334155), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Cash Received from Customer',
                                          style: TextStyle(
                                            color: Color(0xFF1E293B),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Clean White Input Box with Large Currency Text
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x06000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                      child: Row(
                                        children: [
                                          Text(
                                            widget.currency,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _cashTenderedController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                                letterSpacing: -0.4,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                                              ),
                                              onChanged: (_) {
                                                _clearError();
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                          if (_cashTenderedController.text.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                              onPressed: () {
                                                _cashTenderedController.clear();
                                                setState(() {});
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Return Change Pill Card
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isCashDeficit ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: isCashDeficit ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: isCashDeficit ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isCashDeficit
                                                      ? Icons.warning_amber_rounded
                                                      : Icons.published_with_changes_rounded,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                isCashDeficit ? 'Deficit Shortage' : 'Return Change to Customer',
                                                style: TextStyle(
                                                  color: isCashDeficit ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Flexible(
                                            child: Text(
                                              isCashDeficit
                                                  ? '-${widget.currency}${(payableAmount - cashTendered).toStringAsFixed(2)}'
                                                  : '${widget.currency}${changeAmount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: isCashDeficit ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_selectedMethod == 'UPI') ...[
                              // UPI DETAILS CONTAINER
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Dynamic QR Code Render Box
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: _isGeneratingQr
                                          ? const SizedBox(
                                              width: 140,
                                              height: 140,
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF16A34A)),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Generating QR...',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        color: Color(0xFF64748B),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : (_dynamicQrResult != null && _dynamicQrResult!.qrIntentUrl.isNotEmpty)
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: QrImageView(
                                                    data: _dynamicQrResult!.qrIntentUrl,
                                                    version: QrVersions.auto,
                                                    size: 140.0,
                                                    backgroundColor: Colors.white,
                                                    gapless: true,
                                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                                  ),
                                                )
                                              : SizedBox(
                                                  width: 140,
                                                  height: 140,
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.qr_code_2_rounded, size: 44, color: Color(0xFF94A3B8)),
                                                        const SizedBox(height: 4),
                                                        TextButton.icon(
                                                          onPressed: () => _fetchDynamicUpiQr(roundedTotal),
                                                          icon: const Icon(Icons.refresh_rounded, size: 13),
                                                          label: const Text('Retry QR', style: TextStyle(fontSize: 10.5)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                    ),
                                    const SizedBox(height: 10),

                                    // UPI Scan Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFDCFCE7)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.qr_code_scanner_rounded, size: 13, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Scan & Pay with Any UPI App • ${widget.currency}${payableAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF15803D),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Auto-detect pulse status
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 7,
                                          height: 7,
                                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF16A34A)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Awaiting payment... Expires in ${_formatSeconds(_upiExpirySeconds)}',
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_selectedMethod == 'Card') ...[
                              // CARD POS TERMINAL CONTAINER
                              Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.credit_card_rounded, color: Color(0xFF7E22CE), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Card Provider',
                                          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _buildCardTypeChip('Visa / Mastercard'),
                                        const SizedBox(width: 6),
                                        _buildCardTypeChip('RuPay'),
                                        const SizedBox(width: 6),
                                        _buildCardTypeChip('Amex'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.point_of_sale_rounded, color: Color(0xFF7E22CE), size: 19),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Swipe / Dip / Tap card on physical POS machine, then confirm payment below.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF334155),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_selectedMethod == 'Split') ...[
                              // SPLIT CONTAINER
                              Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.call_split_rounded, color: Color(0xFFEA580C), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Split Payment Amounts',
                                          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildSplitRow('Cash', _splitCashCtrl, Icons.payments_rounded, const Color(0xFF2563EB)),
                                    const SizedBox(height: 6),
                                    _buildSplitRow('Card', _splitCardCtrl, Icons.credit_card_rounded, const Color(0xFF9333EA)),
                                    const SizedBox(height: 6),
                                    _buildSplitRow('UPI', _splitUpiCtrl, Icons.qr_code_2_rounded, const Color(0xFF16A34A)),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: splitRemaining == 0
                                            ? const Color(0xFFECFDF5)
                                            : (splitRemaining > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7)),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: splitRemaining == 0
                                              ? const Color(0xFFA7F3D0)
                                              : (splitRemaining > 0 ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            splitRemaining == 0
                                                ? 'Split Balanced!'
                                                : (splitRemaining > 0 ? 'Remaining to Split:' : 'Excess Split Entered:'),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: splitRemaining == 0
                                                  ? const Color(0xFF047857)
                                                  : (splitRemaining > 0 ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                                            ),
                                          ),
                                          Text(
                                            '${widget.currency}${splitRemaining.abs().toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: splitRemaining == 0
                                                  ? const Color(0xFF047857)
                                                  : (splitRemaining > 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 5. PRIMARY ACTION CTA (Full-Width Royal Blue Button)
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : () => _validateAndSubmitPayment(context, payableAmount, roundOff),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSubmitting ? const Color(0xFF94A3B8) : const Color(0xFF1D4ED8),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSubmitting) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Processing Payment...',
                                      style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                                    ),
                                  ] else ...[
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 7),
                                    Text(
                                      'Complete Payment • ${widget.currency}${payableAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
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
            ),
          ),
        ),
      ],
    );
  }

  String _formatSeconds(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildPastelMethodCard({
    required String method,
    required IconData icon,
    required Color bgColor,
    required Color iconBgColor,
    required Color activeBorderColor,
    required Color inactiveBorderColor,
    required Color iconColor,
    required Color textColor,
    required double roundedTotal,
    required double roundOff,
  }) {
    final bool isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
        if (method == 'UPI') {
          _startUpiPolling(roundedTotal, roundOff);
        } else {
          _stopUpiPolling();
          _stopExpiryCountdown();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeBorderColor : inactiveBorderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeBorderColor.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              method,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTypeChip(String type) {
    final bool isSelected = _selectedCardType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCardType = type;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7E22CE) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF7E22CE) : const Color(0xFFCBD5E1),
              width: 1.1,
            ),
          ),
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitRow(String method, TextEditingController ctrl, IconData icon, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 4),
              Text(
                method,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '${widget.currency} ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (_) {
                _clearError();
                setState(() {});
              },
            ),
          ),
        ),
      ],
    );
  }
}

