import 'dart:async';
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
  String? _upiTransactionRef;
  Timer? _upiPollingTimer;

  // Dynamic QR & Verification State
  bool _isGeneratingQr = false;
  PaymentQrResult? _dynamicQrResult;
  int _upiExpirySeconds = 300; // 5 minutes countdown
  Timer? _expiryCountdownTimer;
  final _manualUtrController = TextEditingController();
  bool _showManualUtr = false;

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
    _manualUtrController.dispose();
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
          : (widget.order.id.length > 8 ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase() : widget.order.id);

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
    if (_isUpiPaymentConfirmed) return;
    _stopUpiPolling();
    _stopExpiryCountdown();

    HapticFeedback.heavyImpact();

    final String finalRef = utr ?? paymentId ?? 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    setState(() {
      _isUpiPaymentConfirmed = true;
      _upiTransactionRef = finalRef;
    });

    final nav = Navigator.of(context);
    // Display animated success screen briefly before closing
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final String finalMethod = 'UPI (UTR: $_upiTransactionRef)';
    nav.pop(PaymentModalResult(
      paymentMethod: finalMethod,
      roundOff: roundOff,
      totalAmount: roundedAmount,
    ));
  }

  void _submitManualUtrPayment(double roundedAmount, double roundOff) {
    final utrText = _manualUtrController.text.trim();
    if (utrText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 12-digit UPI UTR / Ref Number';
      });
      return;
    }
    _onUpiPaymentAutoVerified(roundedAmount, roundOff, utr: utrText);
  }

  void _validateAndSubmitPayment(
    BuildContext context,
    double payableAmount,
    double roundOff,
  ) async {
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

  Color _getOrderTypeBadgeColor() {
    switch (widget.order.orderType) {
      case OrderType.delivery:
        return const Color(0xFF059669); // Emerald Green
      case OrderType.takeaway:
        return const Color(0xFFD97706); // Amber
      case OrderType.dineIn:
        return const Color(0xFF0284C7); // Sky Blue / Navy
    }
  }

  String _formatTimer(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final double rawTotal = widget.order.totalAmount;
    final double roundedTotal = rawTotal.roundToDouble();
    final double roundOff = roundedTotal - rawTotal;
    final bool isRoundOffApplicable = (_selectedMethod == 'Cash' || _selectedMethod == 'UPI');
    final double payableAmount = isRoundOffApplicable ? roundedTotal : rawTotal;

    final double cashTendered = double.tryParse(_cashTenderedController.text) ?? payableAmount;
    final double changeAmount = (cashTendered - payableAmount).clamp(0.0, 99999.0);
    final bool isCashDeficit = cashTendered < payableAmount;

    final double splitCash = double.tryParse(_splitCashCtrl.text) ?? 0.0;
    final double splitCard = double.tryParse(_splitCardCtrl.text) ?? 0.0;
    final double splitUpi = double.tryParse(_splitUpiCtrl.text) ?? 0.0;
    final double splitTotal = splitCash + splitCard + splitUpi;
    final double splitRemaining = payableAmount - splitTotal;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar (Wrapped & Adaptive)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF051C48).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF051C48), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              const Text(
                                'Payment Checkout',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getOrderTypeBadgeColor().withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _getOrderTypeBadgeColor().withValues(alpha: 0.3), width: 0.8),
                                ),
                                child: Text(
                                  _getOrderTypeLabel(),
                                  style: TextStyle(
                                    color: _getOrderTypeBadgeColor(),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Order #${widget.order.id.length > 8 ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase() : widget.order.id} • ${widget.order.items.length} items',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _stopUpiPolling();
                        _stopExpiryCountdown();
                        Navigator.pop(context, null);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF475569), size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Total Payable Card (Wrapped to eliminate pixel overflow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF051C48),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14051C48),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TOTAL PAYABLE',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  'Sub: ${widget.currency}${widget.order.subtotal.toStringAsFixed(1)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                if (widget.order.discountAmount > 0) ...[
                                  const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text(
                                    'Disc: -${widget.currency}${widget.order.discountAmount.toStringAsFixed(1)}',
                                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                                if (widget.order.taxAmount > 0) ...[
                                  const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text(
                                    'Tax: ${widget.currency}${widget.order.taxAmount.toStringAsFixed(1)}',
                                    style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11),
                                  ),
                                ],
                                if (isRoundOffApplicable && roundOff != 0.0) ...[
                                  const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text(
                                    'Rnd: ${roundOff > 0 ? "+" : ""}${widget.currency}${roundOff.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.currency}${payableAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (isRoundOffApplicable && roundOff != 0.0)
                            Text(
                              'Exact: ${widget.currency}${rawTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10.5,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Method Selector Chips
                Row(
                  children: [
                    Expanded(child: _buildPaymentMethodChip('Cash', Icons.payments_rounded, roundedTotal, roundOff)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPaymentMethodChip('UPI', Icons.qr_code_2_rounded, roundedTotal, roundOff)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPaymentMethodChip('Card', Icons.credit_card_rounded, roundedTotal, roundOff)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPaymentMethodChip('Split', Icons.call_split_rounded, roundedTotal, roundOff)),
                  ],
                ),
                const SizedBox(height: 14),

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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // DYNAMIC METHOD CONTENT
                if (_selectedMethod == 'Cash') ...[
                  // Cash Tendered & Change Section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cash Received from Customer',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _cashTenderedController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 8),
                              child: Text(
                                widget.currency,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _cashTenderedController.clear();
                                setState(() {});
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            _clearError();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),

                        // Quick Tender Buttons
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildQuickTenderChip('Exact', payableAmount),
                            _buildQuickTenderChip(
                              '${widget.currency}${((payableAmount / 50).ceil() * 50)}',
                              ((payableAmount / 50).ceil() * 50).toDouble(),
                            ),
                            _buildQuickTenderChip(
                              '${widget.currency}${((payableAmount / 100).ceil() * 100)}',
                              ((payableAmount / 100).ceil() * 100).toDouble(),
                            ),
                            _buildQuickTenderChip(
                              '${widget.currency}${((payableAmount / 500).ceil() * 500)}',
                              ((payableAmount / 500).ceil() * 500).toDouble(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Return Change Output Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCashDeficit ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCashDeficit ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCashDeficit ? Icons.warning_amber_rounded : Icons.change_circle_rounded,
                                    color: isCashDeficit ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCashDeficit ? 'Deficit Shortage:' : 'Return Change to Customer:',
                                    style: TextStyle(
                                      color: isCashDeficit ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Flexible(
                                child: Text(
                                  isCashDeficit
                                      ? '-${widget.currency}${(payableAmount - cashTendered).toStringAsFixed(1)}'
                                      : '${widget.currency}${changeAmount.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    color: isCashDeficit ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
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
                  // PRODUCTION DYNAMIC RAZORPAY / GATEWAY UPI SCREEN
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gateway Brand / Header Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF051C48).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF051C48), size: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _dynamicQrResult?.isDynamicGateway == true
                                      ? 'Razorpay Dynamic UPI'
                                      : 'Instant UPI Payment',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            // Countdown Expiry Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _upiExpirySeconds > 30 ? const Color(0xFFF1F5F9) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _upiExpirySeconds > 30 ? const Color(0xFFCBD5E1) : const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 12,
                                    color: _upiExpirySeconds > 30 ? const Color(0xFF475569) : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimer(_upiExpirySeconds),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _upiExpirySeconds > 30 ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Dynamic QR Code Render Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _isGeneratingQr
                              ? const SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF051C48)),
                                        SizedBox(height: 10),
                                        Text(
                                          'Generating QR...',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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
                                        size: 160.0,
                                        backgroundColor: Colors.white,
                                        gapless: true,
                                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                                      ),
                                    )
                                  : SizedBox(
                                      width: 160,
                                      height: 160,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.qr_code_2_rounded, size: 50, color: Color(0xFF94A3B8)),
                                            const SizedBox(height: 6),
                                            TextButton.icon(
                                              onPressed: () => _fetchDynamicUpiQr(roundedTotal),
                                              icon: const Icon(Icons.refresh_rounded, size: 14),
                                              label: const Text('Retry QR', style: TextStyle(fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                        ),
                        const SizedBox(height: 10),

                        // Amount to pay pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF051C48).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Scan with GPay, PhonePe, Paytm, BHIM • ${widget.currency}${payableAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Real-Time Auto-Verification Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isUpiPaymentConfirmed ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isUpiPaymentConfirmed ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isUpiPaymentConfirmed) ...[
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Payment Verified! Ref: $_upiTransactionRef',
                                    style: const TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Waiting for customer payment...',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Manual UTR Fallback Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showManualUtr = !_showManualUtr;
                                });
                              },
                              icon: Icon(
                                _showManualUtr ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: const Color(0xFF64748B),
                              ),
                              label: Text(
                                _showManualUtr ? 'Hide Manual Verification' : 'Manual UTR / Bank Ref Entry',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                            TextButton.icon(
                              onPressed: () => _fetchDynamicUpiQr(roundedTotal),
                              icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF051C48)),
                              label: const Text(
                                'Regenerate',
                                style: TextStyle(fontSize: 11, color: Color(0xFF051C48), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        if (_showManualUtr) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _manualUtrController,
                                  keyboardType: TextInputType.text,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: 'Enter 12-digit UTR / Ref ID',
                                    hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _submitManualUtrPayment(roundedTotal, roundOff),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF051C48),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else if (_selectedMethod == 'Card') ...[
                  // Card POS Terminal View
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Card Provider',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.point_of_sale_rounded, color: Color(0xFF051C48), size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Swipe / Dip / Tap card on physical POS terminal, then click Complete Payment.',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedMethod == 'Split') ...[
                  // Split Multi-tender Section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Split Amounts',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        _buildSplitRow('Cash', _splitCashCtrl, Icons.payments_rounded),
                        const SizedBox(height: 8),
                        _buildSplitRow('Card', _splitCardCtrl, Icons.credit_card_rounded),
                        const SizedBox(height: 8),
                        _buildSplitRow('UPI', _splitUpiCtrl, Icons.qr_code_2_rounded),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: splitRemaining == 0
                                ? const Color(0xFFECFDF5)
                                : (splitRemaining > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                splitRemaining == 0
                                    ? 'Exact Split Balanced!'
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
                                '${widget.currency}${splitRemaining.abs().toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 13,
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

                const SizedBox(height: 18),

                // Submit / Confirm Button (Hidden for UPI automated polling unless fallback)
                if (_selectedMethod != 'UPI') ...[
                  ElevatedButton(
                    onPressed: () => _validateAndSubmitPayment(context, payableAmount, roundOff),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF051C48),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Complete Payment • ${widget.currency}${payableAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip(
    String method,
    IconData icon,
    double roundedTotal,
    double roundOff,
  ) {
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF051C48) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF051C48) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF475569),
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              method,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTenderChip(String label, double value) {
    return InkWell(
      onTap: () {
        _cashTenderedController.text = value.toStringAsFixed(0);
        _clearError();
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
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
            color: isSelected ? const Color(0xFF051C48) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitRow(String method, TextEditingController ctrl, IconData icon) {
    return Row(
      children: [
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF051C48)),
              const SizedBox(width: 4),
              Text(
                method,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${widget.currency} ',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            onChanged: (_) {
              _clearError();
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}
