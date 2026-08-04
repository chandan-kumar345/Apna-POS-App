import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/models/order_model.dart';

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
  String _selectedMethod = 'UPI';
  bool _isProcessing = false;
  final _cashTenderedController = TextEditingController();
  final _splitCashCtrl = TextEditingController();
  final _splitCardCtrl = TextEditingController();
  final _splitUpiCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final double cashTendered = double.tryParse(_cashTenderedController.text) ?? widget.order.totalAmount;
    final double changeAmount = (cashTendered - widget.order.totalAmount).clamp(0, 99999);

    final double splitCash = double.tryParse(_splitCashCtrl.text) ?? 0.0;
    final double splitCard = double.tryParse(_splitCardCtrl.text) ?? 0.0;
    final double splitUpi = double.tryParse(_splitUpiCtrl.text) ?? 0.0;
    final double splitTotal = splitCash + splitCard + splitUpi;
    final double splitRemaining = widget.order.totalAmount - splitTotal;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: SingleChildScrollView(
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            blurStrength: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Payment Mode',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Complete order billing transaction',
                            style: TextStyle(fontSize: 12, color: GlassTheme.textMedium),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: GlassTheme.textMedium),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Total Payable Box
                GlassContainer(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: GlassTheme.primaryViolet.withOpacity(0.18),
                  borderColor: GlassTheme.primaryViolet.withOpacity(0.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount Payable', style: TextStyle(color: Colors.white, fontSize: 13)),
                      Text(
                        '${widget.currency}${widget.order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: GlassTheme.accentNeonGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Options (Requirement 10)
                Row(
                  children: [
                    _buildPaymentTab('UPI', Icons.qr_code_2_rounded, 'Instant QR'),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Card', Icons.credit_card_rounded, 'POS Swiper'),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Cash', Icons.payments_rounded, 'Tender Cash'),
                    const SizedBox(width: 6),
                    _buildPaymentTab('Split', Icons.call_split_rounded, 'Multi Mode'),
                  ],
                ),
                const SizedBox(height: 18),

                // Method Details View
                if (_selectedMethod == 'UPI') ...[
                  GlassContainer(
                    padding: const EdgeInsets.all(12),
                    backgroundColor: GlassTheme.glassInput,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 110,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scan QR via GPay, PhonePe, Paytm or Cred',
                          style: TextStyle(color: GlassTheme.textMedium, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedMethod == 'Cash') ...[
                  GlassTextField(
                    controller: _cashTenderedController,
                    labelText: 'Cash Received from Customer',
                    hintText: widget.order.totalAmount.toStringAsFixed(0),
                    prefixIcon: Icons.money_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change to Return:', style: TextStyle(color: GlassTheme.textMedium, fontSize: 12)),
                      Text(
                        '${widget.currency}${changeAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: GlassTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ] else if (_selectedMethod == 'Split') ...[
                  // Split / Partial Payment Text Fields (Requirement 10)
                  GlassContainer(
                    padding: const EdgeInsets.all(14),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Partial Payment Entry (Cash + Card + UPI)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GlassTextField(
                                controller: _splitCashCtrl,
                                labelText: 'Cash Paid',
                                hintText: '0',
                                prefixIcon: Icons.money,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassTextField(
                                controller: _splitCardCtrl,
                                labelText: 'Card Paid',
                                hintText: '0',
                                prefixIcon: Icons.credit_card,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassTextField(
                                controller: _splitUpiCtrl,
                                labelText: 'UPI Paid',
                                hintText: '0',
                                prefixIcon: Icons.qr_code,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Entered Total: ${widget.currency}${splitTotal.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              splitRemaining <= 0 ? 'Full Amount Covered!' : 'Remaining: ${widget.currency}${splitRemaining.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: splitRemaining <= 0 ? GlassTheme.accentNeonGreen : GlassTheme.accentAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GlassTheme.glassInput,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.point_of_sale, color: GlassTheme.primaryCyan, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tap or Swipe card on external POS Terminal machine.',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                GlassButton(
                  label: 'Confirm Payment & Print Receipt',
                  icon: Icons.check_circle_rounded,
                  height: 44,
                  isSecondary: _selectedMethod == 'UPI',
                  isLoading: _isProcessing,
                  onPressed: () async {
                    setState(() => _isProcessing = true);
                    final nav = Navigator.of(context);
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (!mounted) return;
                    final finalMethod = _selectedMethod == 'Split'
                        ? 'Split (Cash: ₹${splitCash.toStringAsFixed(0)}, Card: ₹${splitCard.toStringAsFixed(0)}, UPI: ₹${splitUpi.toStringAsFixed(0)})'
                        : _selectedMethod;

                    nav.pop(finalMethod);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTab(String method, IconData icon, String sub) {
    final isSel = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSel ? GlassTheme.primaryViolet.withOpacity(0.3) : GlassTheme.glassInput,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? GlassTheme.primaryViolet : GlassTheme.glassBorder,
              width: isSel ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? GlassTheme.primaryCyan : GlassTheme.textMedium, size: 20),
              const SizedBox(height: 4),
              Text(
                method,
                style: TextStyle(
                  color: isSel ? Colors.white : GlassTheme.textMedium,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(color: GlassTheme.textLow, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
