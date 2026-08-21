import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/order_model.dart';
import '../../core/database/database_service.dart';

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
  bool _isProcessing = false;
  bool _isUpiPaymentConfirmed = false;
  String? _upiTransactionRef;
  Timer? _upiPollingTimer;

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
    _cashTenderedController.dispose();
    _splitCashCtrl.dispose();
    _splitCardCtrl.dispose();
    _splitUpiCtrl.dispose();
    super.dispose();
  }

  void _startUpiPolling(double roundedTotal, double roundOff) {
    _stopUpiPolling();
    _upiPollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (!mounted || _selectedMethod != 'UPI' || _isUpiPaymentConfirmed) return;
      final db = DatabaseService();
      final isPaid = await db.checkUpiPaymentStatus(widget.order.id);
      if (isPaid && mounted && !_isUpiPaymentConfirmed) {
        _onUpiPaymentAutoVerified(roundedTotal, roundOff);
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
    double roundOff,
  ) async {
    if (_isUpiPaymentConfirmed) return;
    _stopUpiPolling();

    setState(() {
      _isUpiPaymentConfirmed = true;
      _upiTransactionRef = 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    });

    final nav = Navigator.of(context);
    // Display "Payment Done! Generating invoice..." briefly before auto-closing
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final String finalMethod = 'UPI (Ref: $_upiTransactionRef)';
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

    setState(() => _isProcessing = true);
    final nav = Navigator.of(context);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    String finalMethod = _selectedMethod;
    if (_selectedMethod == 'Cash') {
      finalMethod = 'Cash (Rec: ${widget.currency}${cashTendered.toStringAsFixed(0)})';
    } else if (_selectedMethod == 'Card') {
      finalMethod = 'Card ($_selectedCardType)';
    } else if (_selectedMethod == 'Split') {
      finalMethod =
          'Split (Cash: ${widget.currency}${splitCash.toStringAsFixed(0)}, Card: ${widget.currency}${splitCard.toStringAsFixed(0)}, UPI: ${widget.currency}${splitUpi.toStringAsFixed(0)})';
    }

    nav.pop(PaymentModalResult(
      paymentMethod: finalMethod,
      roundOff: (_selectedMethod == 'Cash' || _selectedMethod == 'UPI') ? roundOff : 0.0,
      totalAmount: payableAmount,
      cashTendered: _selectedMethod == 'Cash' ? cashTendered : null,
    ));
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
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF051C48).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.order.tableNumber ?? 'Dine-In',
                                  style: const TextStyle(
                                    color: Color(0xFF051C48),
                                    fontSize: 10,
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
                                if (widget.order.taxAmount > 0) ...[
                                  const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text(
                                    'Tax: ${widget.currency}${widget.order.taxAmount.toStringAsFixed(1)}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                                if (isRoundOffApplicable && roundOff.abs() > 0.001) ...[
                                  const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text(
                                    'Round: ${roundOff >= 0 ? '+' : ''}${widget.currency}${roundOff.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${widget.currency}${payableAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Mode Selector Tabs (Cash First)
                Row(
                  children: [
                    _buildPaymentTab('Cash', Icons.payments_rounded, roundedTotal, roundOff),
                    const SizedBox(width: 6),
                    _buildPaymentTab('UPI', Icons.qr_code_2_rounded, roundedTotal, roundOff),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Card', Icons.credit_card_rounded, roundedTotal, roundOff),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Split', Icons.call_split_rounded, roundedTotal, roundOff),
                  ],
                ),
                const SizedBox(height: 14),

                // Active Mode Details View
                if (_selectedMethod == 'Cash') ...[
                  // Clean Cash View (No price selection chips)
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cash Received',
                              style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            if (roundOff.abs() > 0.001)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF051C48).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Rounded: ${widget.currency}${roundedTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Color(0xFF051C48), fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _cashTenderedController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            _clearError();
                            setState(() {});
                          },
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: roundedTotal.toStringAsFixed(0),
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF051C48), size: 19),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                        ),
                        const SizedBox(height: 12),

                        // Change to Return Box (Wrapped & Adaptive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCashDeficit ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCashDeficit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  isCashDeficit ? 'Shortage Amount:' : 'Change to Return:',
                                  style: TextStyle(
                                    color: isCashDeficit ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isCashDeficit
                                      ? '${widget.currency}${(payableAmount - cashTendered).toStringAsFixed(2)} short'
                                      : '${widget.currency}${changeAmount.toStringAsFixed(2)}',
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
                  // Automated UPI Screen (No manual buttons, real-time status listener)
                  Builder(
                    builder: (context) {
                      final db = DatabaseService();
                      final String merchantUpiId = (db.restaurant?.upiId ?? '').isNotEmpty
                          ? db.restaurant!.upiId
                          : 'apnapos@upi';
                      final String merchantName = (db.restaurant?.name ?? '').isNotEmpty
                          ? db.restaurant!.name
                          : 'Apna POS Store';
                      final String orderShortId = widget.order.id.length > 6
                          ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase()
                          : widget.order.id;

                      final String upiUri =
                          'upi://pay?pa=$merchantUpiId&pn=${Uri.encodeComponent(merchantName)}&am=${roundedTotal.toStringAsFixed(2)}&cu=INR&tn=Order_$orderShortId';
                      final String qrCodeUrl =
                          'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(upiUri)}';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Compact Dynamic QR Code Box
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  qrCodeUrl,
                                  width: 145,
                                  height: 145,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      width: 145,
                                      height: 145,
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox(
                                      width: 145,
                                      height: 145,
                                      child: Center(
                                        child: Icon(Icons.qr_code_2_rounded, size: 70, color: Color(0xFF051C48)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Clean Single-Line VPA Copy Pill
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: merchantUpiId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('UPI ID ($merchantUpiId) copied!'),
                                    backgroundColor: const Color(0xFF051C48),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF051C48).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy_rounded, color: Color(0xFF051C48), size: 12),
                                    const SizedBox(width: 5),
                                    Text(
                                      merchantUpiId,
                                      style: const TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Automated Real-Time Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isUpiPaymentConfirmed ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isUpiPaymentConfirmed ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isUpiPaymentConfirmed) ...[
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 16),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Payment Done! Generating Invoice...',
                                      style: TextStyle(
                                        color: Color(0xFF047857),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Waiting for payment confirmation',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                              Icon(Icons.point_of_sale_rounded, color: Color(0xFF051C48), size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Card POS Terminal Ready', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                                    SizedBox(height: 2),
                                    Text('Tap, Insert, or Swipe card on device.', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedMethod == 'Split') ...[
                  // Multi-Mode Split View
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
                          'Split Payment (Cash + Card + UPI)',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildSplitInputField('Cash', _splitCashCtrl),
                            const SizedBox(width: 6),
                            _buildSplitInputField('Card', _splitCardCtrl),
                            const SizedBox(width: 6),
                            _buildSplitInputField('UPI', _splitUpiCtrl),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: splitRemaining <= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: splitRemaining <= 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Entered: ${widget.currency}${splitTotal.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                              Text(
                                splitRemaining <= 0
                                    ? 'Full Amount Covered!'
                                    : 'Remaining: ${widget.currency}${splitRemaining.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: splitRemaining <= 0 ? const Color(0xFF047857) : const Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        InkWell(
                          onTap: _clearError,
                          child: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 16),
                        ),
                      ],
                    ),
                  ),
                ],

                // Bottom Action Button: Rendered ONLY for Cash, Card, Split (UPI is fully automated without buttons)
                if (_selectedMethod != 'UPI') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _validateAndSubmitPayment(context, payableAmount, roundOff),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        disabledBackgroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isProcessing ? 'Processing...' : 'Confirm & Print Receipt',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
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

  Widget _buildPaymentTab(String method, IconData icon, double roundedTotal, double roundOff) {
    final isSel = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMethod = method;
            _errorMessage = null;
          });
          if (method == 'UPI') {
            _startUpiPolling(roundedTotal, roundOff);
          } else {
            _stopUpiPolling();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF051C48) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? const Color(0xFF051C48) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? Colors.white : const Color(0xFF475569), size: 18),
              const SizedBox(height: 3),
              Text(
                method,
                style: TextStyle(
                  color: isSel ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardTypeChip(String type) {
    final isSel = _selectedCardType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedCardType = type);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF051C48).withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSel ? const Color(0xFF051C48) : const Color(0xFFCBD5E1)),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: isSel ? const Color(0xFF051C48) : const Color(0xFF475569),
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitInputField(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 10.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          SizedBox(
            height: 34,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                _clearError();
                setState(() {});
              },
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
