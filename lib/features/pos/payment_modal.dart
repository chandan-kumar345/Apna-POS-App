import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/order_model.dart';
import '../../core/database/database_service.dart';

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
  String _selectedMethod = 'UPI'; // 'UPI', 'Cash', 'Card', 'Split'
  bool _isProcessing = false;
  bool _isUpiPaymentConfirmed = false;
  String? _upiTransactionRef;

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
    _cashTenderedController.text = widget.order.totalAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashTenderedController.dispose();
    _splitCashCtrl.dispose();
    _splitCardCtrl.dispose();
    _splitUpiCtrl.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _confirmUpiPaymentAndAutoGenerateOrder(BuildContext context, double totalAmount) async {
    if (_isProcessing || _isUpiPaymentConfirmed) return;
    _clearError();

    setState(() {
      _isProcessing = true;
      _isUpiPaymentConfirmed = true;
      _upiTransactionRef = 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ UPI Payment Confirmed! Generating Order & Invoice...'),
        backgroundColor: const Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final nav = Navigator.of(context);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final String finalMethod = 'UPI (Ref: $_upiTransactionRef)';
    nav.pop(finalMethod);
  }

  void _validateAndSubmitPayment(BuildContext context, double totalAmount) async {
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
        showError('Please enter the cash amount before confirming payment.');
        return;
      }
      if (parsedCash == null || cashTendered <= 0) {
        showError('Please enter a valid cash amount.');
        return;
      }
      if (cashTendered < totalAmount) {
        final double shortAmount = totalAmount - cashTendered;
        showError('Tendered amount is ${widget.currency}${shortAmount.toStringAsFixed(1)} short. Please enter full amount.');
        return;
      }
    }

    // 2. Split Mode Validation
    if (_selectedMethod == 'Split') {
      if (rawSplitCash.isEmpty && rawSplitCard.isEmpty && rawSplitUpi.isEmpty) {
        showError('Please fill in the split payment amounts before confirming.');
        return;
      }
      if (splitTotal <= 0) {
        showError('Please enter a valid split payment amount.');
        return;
      }
      if (splitTotal < totalAmount) {
        final double shortAmount = totalAmount - splitTotal;
        showError('Entered split total is ${widget.currency}${shortAmount.toStringAsFixed(1)} short. Please cover full amount.');
        return;
      }
    }

    // Validation passed — Proceed with payment confirmation
    setState(() => _isProcessing = true);
    final nav = Navigator.of(context);
    await Future.delayed(const Duration(milliseconds: 350));
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

    nav.pop(finalMethod);
  }

  @override
  Widget build(BuildContext context) {
    final double totalAmount = widget.order.totalAmount;
    final double cashTendered = double.tryParse(_cashTenderedController.text) ?? totalAmount;
    final double changeAmount = (cashTendered - totalAmount).clamp(0.0, 99999.0);
    final bool isCashDeficit = cashTendered < totalAmount;

    final double splitCash = double.tryParse(_splitCashCtrl.text) ?? 0.0;
    final double splitCard = double.tryParse(_splitCardCtrl.text) ?? 0.0;
    final double splitUpi = double.tryParse(_splitUpiCtrl.text) ?? 0.0;
    final double splitTotal = splitCash + splitCard + splitUpi;
    final double splitRemaining = totalAmount - splitTotal;

    // Condition: If tax is 0, do not display tax
    final String subtotalTaxText = widget.order.taxAmount > 0
        ? 'Subtotal: ${widget.currency}${widget.order.subtotal.toStringAsFixed(1)} | Tax: ${widget.currency}${widget.order.taxAmount.toStringAsFixed(1)}'
        : 'Subtotal: ${widget.currency}${widget.order.subtotal.toStringAsFixed(1)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF051C48).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF051C48), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Payment Checkout',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF051C48).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.order.tableNumber ?? 'Dine-In',
                                  style: const TextStyle(
                                    color: Color(0xFF051C48),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Order #${widget.order.id.length > 8 ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase() : widget.order.id} • ${widget.order.items.length} items',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(6),
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
                const SizedBox(height: 12),

                // Total Amount Payable Card (Clean Semi Curved Box)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 1),
                          Text(
                            subtotalTaxText,
                            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                          ),
                        ],
                      ),
                      Text(
                        '${widget.currency}${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Mode Selector Tabs
                Row(
                  children: [
                    _buildPaymentTab('UPI', Icons.qr_code_2_rounded),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Cash', Icons.payments_rounded),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Card', Icons.credit_card_rounded),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Split', Icons.call_split_rounded),
                  ],
                ),
                const SizedBox(height: 12),

                // Active Mode Details View
                if (_selectedMethod == 'UPI') ...[
                  // UPI QR View (Dynamic NPCI standard exact-amount QR code linked to merchant UPI ID)
                  Builder(
                    builder: (context) {
                      final db = DatabaseService();
                      final String merchantUpiId = (db.restaurant?.upiId ?? '').isNotEmpty
                          ? db.restaurant!.upiId
                          : 'apnapos@upi';
                      final String merchantName = (db.restaurant?.name ?? '').isNotEmpty
                          ? db.restaurant!.name
                          : 'Apna POS Merchant';
                      final String orderShortId = widget.order.id.length > 6
                          ? widget.order.id.substring(widget.order.id.length - 6).toUpperCase()
                          : widget.order.id;

                      final String upiUri =
                          'upi://pay?pa=$merchantUpiId&pn=${Uri.encodeComponent(merchantName)}&am=${totalAmount.toStringAsFixed(2)}&cu=INR&tn=Order_$orderShortId';
                      final String qrCodeUrl =
                          'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiUri)}';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x10000000),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      qrCodeUrl,
                                      width: 125,
                                      height: 125,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const SizedBox(
                                          width: 125,
                                          height: 125,
                                          child: Center(
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return const SizedBox(
                                          width: 125,
                                          height: 125,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.qr_code_2_rounded, size: 60, color: Color(0xFF051C48)),
                                              SizedBox(height: 2),
                                              Text('Exact UPI QR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan to Pay ${widget.currency}${totalAmount.toStringAsFixed(2)} directly to $merchantName',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Supports GPay, PhonePe, Paytm, Cred & BHIM UPI',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: merchantUpiId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('UPI ID ($merchantUpiId) Copied to Clipboard!'),
                                    backgroundColor: const Color(0xFF051C48),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF051C48).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy_rounded, color: Color(0xFF051C48), size: 13),
                                    const SizedBox(width: 5),
                                    Text('VPA: $merchantUpiId', style: const TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // UPI Payment Status / Instant Verification Action
                            if (_isUpiPaymentConfirmed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'UPI Payment Verified Successfully',
                                            style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11.5),
                                          ),
                                          if (_upiTransactionRef != null)
                                            Text(
                                              'Ref: $_upiTransactionRef • Auto-generating order...',
                                              style: const TextStyle(color: Color(0xFF065F46), fontSize: 10),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF047857)),
                                    ),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                height: 36,
                                child: OutlinedButton.icon(
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _confirmUpiPaymentAndAutoGenerateOrder(context, totalAmount),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF051C48), width: 1.2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    backgroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF051C48)),
                                  label: const Text(
                                    'Verify / Payment Received (Auto-Generate Order)',
                                    style: TextStyle(color: Color(0xFF051C48), fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else if (_selectedMethod == 'Cash') ...[
                  // Cash View
                  Container(
                    padding: const EdgeInsets.all(12),
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
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cashTenderedController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) { _clearError(); setState(() {}); },
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: totalAmount.toStringAsFixed(0),
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF051C48), size: 18),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        const SizedBox(height: 10),

                        // Change to Return Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              Text(
                                isCashDeficit ? 'Shortage Amount:' : 'Change to Return:',
                                style: TextStyle(
                                  color: isCashDeficit ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                              Text(
                                isCashDeficit
                                    ? '${widget.currency}${(totalAmount - cashTendered).toStringAsFixed(2)} short'
                                    : '${widget.currency}${changeAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isCashDeficit ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedMethod == 'Card') ...[
                  // Card POS Terminal View
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Card Provider',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildCardTypeChip('Visa / Mastercard'),
                            const SizedBox(width: 5),
                            _buildCardTypeChip('RuPay'),
                            const SizedBox(width: 5),
                            _buildCardTypeChip('Amex'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('POS Swiper Terminal Ready', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11.5)),
                                    SizedBox(height: 1),
                                    Text('Insert, Tap, or Swipe card on card machine.', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Partial Payment Entry (Cash + Card + UPI)',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Cash Paid Field
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Cash Paid', style: TextStyle(color: Color(0xFF475569), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  SizedBox(
                                    height: 34,
                                    child: TextField(
                                      controller: _splitCashCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) { _clearError(); setState(() {}); },
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
                            ),
                            const SizedBox(width: 5),
                            // Card Paid Field
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Card Paid', style: TextStyle(color: Color(0xFF475569), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  SizedBox(
                                    height: 34,
                                    child: TextField(
                                      controller: _splitCardCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) { _clearError(); setState(() {}); },
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
                            ),
                            const SizedBox(width: 5),
                            // UPI Paid Field
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('UPI Paid', style: TextStyle(color: Color(0xFF475569), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  SizedBox(
                                    height: 34,
                                    child: TextField(
                                      controller: _splitUpiCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) { _clearError(); setState(() {}); },
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              Text(
                                splitRemaining <= 0
                                    ? 'Full Amount Covered!'
                                    : 'Remaining: ${widget.currency}${splitRemaining.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: splitRemaining <= 0 ? const Color(0xFF047857) : const Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
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
                const SizedBox(height: 14),

                // Confirm Payment Button (UPI: Auto-disabled upon success/in progress; Cash/Card/Split: Preserved)
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _selectedMethod == 'UPI'
                        ? (_isProcessing || _isUpiPaymentConfirmed
                            ? null
                            : () => _confirmUpiPaymentAndAutoGenerateOrder(context, totalAmount))
                        : (_isProcessing ? null : () => _validateAndSubmitPayment(context, totalAmount)),
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
                        : const Icon(Icons.check_circle_rounded, size: 17, color: Colors.white),
                    label: Text(
                      _selectedMethod == 'UPI'
                          ? (_isUpiPaymentConfirmed
                              ? 'UPI Payment Confirmed (Processing Order...)'
                              : (_isProcessing ? 'Verifying UPI Payment...' : 'Confirm UPI Payment & Generate Invoice'))
                          : (_isProcessing ? 'Processing Payment...' : 'Confirm Payment & Print Receipt'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildPaymentTab(String method, IconData icon) {
    final isSel = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMethod = method;
            _errorMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
}
