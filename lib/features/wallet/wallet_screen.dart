import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/database/database_service.dart';
import '../../core/services/wallet_service.dart';

/// Communication channel pricing item
class CommunicationPricingItem {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final int credit;
  final String price;

  const CommunicationPricingItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.credit,
    required this.price,
  });
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  final DatabaseService _db = DatabaseService();
  final TextEditingController _amountController = TextEditingController(text: '100');

  // Dynamic balance data initialized from local database (no hardcoded fake values)
  late WalletBalanceData _balanceData;
  bool _isLoading = false;
  bool _isRecharging = false;

  // The 6 communication channels from reference design
  final List<CommunicationPricingItem> _pricingItems = const [
    CommunicationPricingItem(
      title: 'GST Supplier Lookup',
      icon: Icons.search_rounded,
      iconColor: Color(0xFF0284C7),
      iconBgColor: Color(0xFFE0F2FE),
      credit: 1,
      price: '₹2',
    ),
    CommunicationPricingItem(
      title: 'WhatsApp Marketing',
      icon: Icons.chat_bubble_rounded,
      iconColor: Color(0xFF10B981),
      iconBgColor: Color(0xFFDCFCE7),
      credit: 1,
      price: '₹1.09',
    ),
    CommunicationPricingItem(
      title: 'SMS',
      icon: Icons.textsms_rounded,
      iconColor: Color(0xFF475569),
      iconBgColor: Color(0xFFF1F5F9),
      credit: 1,
      price: '₹0.16',
    ),
    CommunicationPricingItem(
      title: 'WhatsApp Utility',
      icon: Icons.settings_rounded,
      iconColor: Color(0xFF0D9488),
      iconBgColor: Color(0xFFCCFBF1),
      credit: 1,
      price: '₹0.215',
    ),
    CommunicationPricingItem(
      title: 'Email',
      icon: Icons.email_rounded,
      iconColor: Color(0xFF4F46E5),
      iconBgColor: Color(0xFFEEF2FF),
      credit: 1,
      price: '₹0.04',
    ),
    CommunicationPricingItem(
      title: 'WhatsApp Authentication',
      icon: Icons.verified_user_rounded,
      iconColor: Color(0xFF1E3A8A),
      iconBgColor: Color(0xFFDBEAFE),
      credit: 1,
      price: '₹0.215',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with actual real data from DatabaseService immediately
    final initialBal = _db.walletBalance;
    _balanceData = WalletBalanceData(
      eligible: initialBal >= 2.0,
      balance: initialBal,
      ebillCharge: 2.0,
      currency: 'INR',
      isActive: true,
      remainingAfterSend: (initialBal - 2.0).clamp(0.0, double.infinity),
      khazanaTotal: initialBal,
      holdAmount: 0.00,
      bonusAmount: 0.00,
      usedBalance: 0.00,
      commissionAmount: 0.00,
      cashbackAmount: 0.00,
    );

    // Fetch dynamic live metrics from backend API
    _loadWalletData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    final data = await _walletService.getWalletDetails();
    if (mounted) {
      setState(() {
        _balanceData = data;
        _isLoading = false;
      });
    }
  }

  void _selectQuickAmount(int amount) {
    HapticFeedback.lightImpact();
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  Future<void> _handleRecharge() async {
    final text = _amountController.text.trim();
    final amount = double.tryParse(text);

    if (amount == null || amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum recharge amount is ₹100'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _showNativePaymentSelectionSheet(amount);
  }

  /// Native UPI Payment Selection Bottom Sheet with 9709593705@ybl
  void _showNativePaymentSelectionSheet(double amount) {
    const String payeeUpiId = '9709593705@ybl';
    final String payeeName = _db.restaurant?.name ?? 'Apna POS';
    final String cleanAmount = amount.toStringAsFixed(2);
    final String upiUri = _walletService.getUpiUriString(
      amount: amount,
      upiId: payeeUpiId,
      payeeName: payeeName,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        bool showQr = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEFF4FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFF059669),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Money via UPI',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Instant Khazana Credit to 9709593705@ybl',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Amount Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payable Amount',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'UPI ID: 9709593705@ybl',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹$cleanAmount',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (!showQr) ...[
                    // Primary Native UPI App Launcher Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C49F), Color(0xFF0072CE)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00C49F).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            await _launchNativeUpiAndConfirm(amount, payeeUpiId, payeeName);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Pay with any UPI App',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Quick App Badges Row (GPay, PhonePe, Paytm, BHIM)
                    Row(
                      children: [
                        _buildUpiAppChip(
                          label: 'PhonePe',
                          color: const Color(0xFF5F259F),
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await _launchNativeUpiAndConfirm(amount, payeeUpiId, payeeName, customScheme: 'phonepe');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildUpiAppChip(
                          label: 'Google Pay',
                          color: const Color(0xFF1A73E8),
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await _launchNativeUpiAndConfirm(amount, payeeUpiId, payeeName, customScheme: 'gpay');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildUpiAppChip(
                          label: 'Paytm',
                          color: const Color(0xFF00B9F1),
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await _launchNativeUpiAndConfirm(amount, payeeUpiId, payeeName, customScheme: 'paytmmp');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Toggle to Scan QR Code / Manual Pay
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setSheetState(() => showQr = true),
                        icon: const Icon(Icons.qr_code_rounded, size: 18, color: Color(0xFF0D9488)),
                        label: const Text(
                          'Or Scan UPI QR Code / Desktop',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Dynamic QR Code Display
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: upiUri,
                          version: QrVersions.auto,
                          size: 150,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'UPI: 9709593705@ybl',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0284C7)),
                            onPressed: () {
                              Clipboard.setData(const ClipboardData(text: payeeUpiId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('UPI ID copied to clipboard: 9709593705@ybl'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _confirmAndRecordPayment(amount, 'QR_SCAN');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'I Have Paid ₹$cleanAmount',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUpiAppChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Launch UPI Intent App and show post-payment verification prompt
  Future<void> _launchNativeUpiAndConfirm(
    double amount,
    String upiId,
    String payeeName, {
    String? customScheme,
  }) async {
    final cleanAmount = amount.toStringAsFixed(2);
    final txnRef = 'REC_${DateTime.now().millisecondsSinceEpoch}';
    final note = Uri.encodeComponent("Khazana Recharge");
    final encName = Uri.encodeComponent(payeeName);

    bool launched = false;

    // 1. If custom scheme requested (e.g. phonepe, paytmmp, gpay)
    if (customScheme != null && customScheme.isNotEmpty) {
      final customUri = Uri.parse(
        '$customScheme://pay?pa=$upiId&pn=$encName&am=$cleanAmount&cu=INR&tn=$note&tr=$txnRef',
      );
      try {
        if (await canLaunchUrl(customUri)) {
          launched = await launchUrl(customUri, mode: LaunchMode.externalApplication);
        } else if (customScheme == 'gpay') {
          // Google Pay on Android doesn't always register gpay://, try Android intent package format
          final gpayIntent = Uri.parse(
            'intent://pay?pa=$upiId&pn=$encName&am=$cleanAmount&cu=INR&tn=$note&tr=$txnRef#Intent;scheme=upi;package=com.google.android.apps.nbu.paisa.user;end',
          );
          if (await canLaunchUrl(gpayIntent)) {
            launched = await launchUrl(gpayIntent, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        debugPrint('[WalletScreen] Custom scheme ($customScheme) launch error: $e');
      }
    }

    // 2. Fallback to standard universal upi://pay intent if not launched yet
    if (!launched) {
      try {
        final genericUri = Uri.parse(
          'upi://pay?pa=$upiId&pn=$encName&am=$cleanAmount&cu=INR&tn=$note&tr=$txnRef',
        );
        if (await canLaunchUrl(genericUri)) {
          launched = await launchUrl(genericUri, mode: LaunchMode.externalApplication);
        } else {
          // Try launching directly without canLaunchUrl check as some Android OEMs restrict canLaunchUrl
          launched = await launchUrl(genericUri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('[WalletScreen] Universal UPI launch error: $e');
      }
    }

    // 3. Show dialog if launched, or inform user to use QR code
    if (!mounted) return;
    if (launched) {
      _showPaymentVerificationDialog(amount);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            customScheme != null
                ? 'Could not open ${customScheme.toUpperCase()}. Please use "Pay with any UPI App" or scan the QR code.'
                : 'No UPI app found. Please scan the QR code to complete payment.',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showPaymentVerificationDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFEFF4FA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 24),
              SizedBox(width: 10),
              Text(
                'Verify UPI Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Text(
            'Did you complete the payment of ₹${amount.toStringAsFixed(2)} to 9709593705@ybl on your UPI app?',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel / Retry', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _confirmAndRecordPayment(amount, 'UPI_INTENT');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Yes, Payment Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndRecordPayment(double amount, String source) async {
    setState(() => _isRecharging = true);
    final messenger = ScaffoldMessenger.of(context);

    final success = await _walletService.rechargeWallet(
      amount: amount,
      referenceId: 'UPI_${DateTime.now().millisecondsSinceEpoch}',
      description: 'Instant UPI Recharge (9709593705@ybl)',
    );

    if (mounted) {
      setState(() => _isRecharging = false);
      if (success) {
        await _loadWalletData();
        messenger.showSnackBar(
          SnackBar(
            content: Text('₹${amount.toStringAsFixed(2)} added to your Khazana successfully!'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to record recharge. Please check your network and try again.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Open Wallet Settings & Rules Modal (Cashback, Minimum Recharge, Khata Tab)
  void _openWalletSettingsModal() {
    bool isEnabled = _db.isWalletEnabled;
    final cashbackCtrl = TextEditingController(text: _db.walletCashbackPercentage.toString());
    final minRechargeCtrl = TextEditingController(text: _db.walletMinRechargeAmount.toString());
    final maxRedeemCtrl = TextEditingController(text: _db.walletMaxRedeemPercentagePerOrder.toString());
    final signupBonusCtrl = TextEditingController(text: _db.walletSignupBonus.toString());
    bool allowNegative = _db.isWalletAllowNegativeBalance;
    final payoutUpiCtrl = TextEditingController(text: _db.walletBusinessPayoutUpi);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFFEFF4FA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Color(0xFF059669), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer & Outlet Wallet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Prepaid Balances, Cashbacks & Payouts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFFCBD5E1), height: 1),
                      const SizedBox(height: 14),

                      // Master Toggle
                      SwitchListTile(
                        value: isEnabled,
                        onChanged: (val) => setModalState(() => isEnabled = val),
                        title: const Text('Enable Wallet System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Allow patrons to recharge prepaid credit and earn cashback', style: TextStyle(fontSize: 10.5)),
                        activeThumbColor: const Color(0xFF059669),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),

                      // Form Inputs
                      Row(
                        children: [
                          Expanded(
                            child: _buildSettingTextField(
                              controller: cashbackCtrl,
                              label: 'Recharge Cashback (%)',
                              hint: '5.0',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSettingTextField(
                              controller: minRechargeCtrl,
                              label: 'Min Recharge (₹)',
                              hint: '200.0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSettingTextField(
                              controller: maxRedeemCtrl,
                              label: 'Max Redeem/Bill (%)',
                              hint: '50.0',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSettingTextField(
                              controller: signupBonusCtrl,
                              label: 'Signup Bonus (₹)',
                              hint: '50.0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: allowNegative,
                        onChanged: (val) => setModalState(() => allowNegative = val),
                        title: const Text('Allow Trusted Negative Credit (Khata Tab)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        activeThumbColor: const Color(0xFF059669),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      _buildSettingTextField(
                        controller: payoutUpiCtrl,
                        label: 'Merchant Payout UPI VPA (Settlements)',
                        hint: 'e.g. 9709593705@ybl',
                      ),
                      const SizedBox(height: 18),

                      // Save Button
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setModalState(() => isSaving = true);
                                  final cb = double.tryParse(cashbackCtrl.text) ?? 5.0;
                                  final mr = double.tryParse(minRechargeCtrl.text) ?? 200.0;
                                  final mrp = double.tryParse(maxRedeemCtrl.text) ?? 50.0;
                                  final sb = double.tryParse(signupBonusCtrl.text) ?? 50.0;
                                  final messenger = ScaffoldMessenger.of(context);

                                  await _db.saveWalletSettings(
                                    enabled: isEnabled,
                                    cashbackPercentage: cb,
                                    minRechargeAmount: mr,
                                    maxRedeemPercentage: mrp,
                                    signupBonus: sb,
                                    allowNegativeBalance: allowNegative,
                                    businessPayoutUpi: payoutUpiCtrl.text,
                                  );

                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Wallet settings saved successfully!'),
                                        backgroundColor: Color(0xFF059669),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save Wallet Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  void _showTransactionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEFF4FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction Ledger',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<List<WalletTransactionItem>>(
                      future: _walletService.getTransactions(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 42,
                                  color: const Color(0xFF94A3B8).withValues(alpha: 0.8),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No transactions recorded yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollCtrl,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = items[index];
                            final isCredit = tx.isCredit;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFCAD7E6).withValues(alpha: 0.5),
                                    offset: const Offset(1, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isCredit ? Icons.add_rounded : Icons.north_east_rounded,
                                      size: 18,
                                      color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.description.isNotEmpty ? tx.description : tx.category,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${tx.createdAt.day} ${_monthName(tx.createdAt.month)} ${tx.createdAt.year}, ${_timeStr(tx.createdAt)}',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isCredit ? "+" : "-"} ₹${tx.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _monthName(int month) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[(month - 1).clamp(0, 11)];
  }

  static String _timeStr(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // Neumorphic decoration builder for outer raised card
  BoxDecoration _neumorphicCardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: const Color(0xFFEEF2F6),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Colors.white,
          offset: Offset(-4, -4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color(0xFFC5D1E0),
          offset: Offset(4, 4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
      border: Border.all(
        color: Colors.white,
        width: 1.2,
      ),
    );
  }

  // Neumorphic sunken well decoration for insets & split balance boxes
  BoxDecoration _neumorphicSunkenDecoration({double radius = 14}) {
    return BoxDecoration(
      color: const Color(0xFFE2E9F2),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: const Color(0xFFCBD5E1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFB8C7D9).withValues(alpha: 0.5),
          offset: const Offset(1, 1),
          blurRadius: 3,
          spreadRadius: 0,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051C48), // Match POS Header Navy
      body: Column(
        children: [
          // 1. POS-Matched Navy Header with Circular Back Button
          _buildPosMatchedHeader(),

          // 2. Neumorphic Curved Corner Body Container
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2F6), // Neumorphic base surface
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF051C48),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWalletData,
                      color: const Color(0xFF051C48),
                      backgroundColor: Colors.white,
                      displacement: 28,
                      strokeWidth: 2.5,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Card 1: Primary Balance Card (showing Available & Used Balance)
                                _buildPrimaryBalanceCard(),

                                const SizedBox(height: 14),

                                // Card 2: 6-Metric Neumorphic Grid
                                _buildSixMetricGrid(),

                                const SizedBox(height: 14),

                                // Card 3: Add Amount (Recharge Section)
                                _buildAddAmountCard(),

                                const SizedBox(height: 14),

                                // Card 4: Communication Pricing Table (with Pull Refresh & Visible Indicator)
                                _buildCommunicationPricingCard(),

                                const SizedBox(height: 14),

                                // Card 5: Wallet Rules & Cashback Settings
                                _buildWalletRulesTile(),

                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. POS-Matched Navy Header with Circular Back Button
  Widget _buildPosMatchedHeader() {
    return Container(
      color: const Color(0xFF051C48), // Match POS Header Color exactly
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        14,
      ),
      child: Row(
        children: [
          // Circular Neumorphic Back Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.maybePop(context);
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Wallet',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Card 1: Primary Balance Card (showing Available & Used Balance in Neumorphic UI)
  Widget _buildPrimaryBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _neumorphicCardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE NOW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_balanceData.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Usable balance after hold amount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
                    SizedBox(width: 4),
                    Text(
                      'Active',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inset Sunken Well displaying USED BALANCE (replaces crossed-out Khazana/On Hold)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _neumorphicSunkenDecoration(radius: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: const Icon(
                    Icons.pie_chart_outline_rounded,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Used Balance',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_balanceData.usedBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 12, color: Color(0xFF7C3AED)),
                      SizedBox(width: 4),
                      Text(
                        'Total Spent',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Footer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Minimum balance to maintain: Rs. 100',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showTransactionsSheet,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Transactions',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: Color(0xFF059669),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2: 6-Metric Neumorphic Grid
  Widget _buildSixMetricGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Khazana Balance',
                value: '₹${_balanceData.balance.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF10B981),
                iconBgColor: const Color(0xFFD1FAE5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Bonus Amount',
                value: '₹${_balanceData.bonusAmount.toStringAsFixed(2)}',
                icon: Icons.card_giftcard_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFE0F2FE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Amount on Hold',
                value: '₹${_balanceData.holdAmount.toStringAsFixed(2)}',
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFEF3C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Used Balance',
                value: '₹${_balanceData.usedBalance.toStringAsFixed(2)}',
                icon: Icons.pie_chart_outline_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBgColor: const Color(0xFFEDE9FE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Commission Amount',
                value: '₹${_balanceData.commissionAmount.toStringAsFixed(2)}',
                icon: Icons.percent_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBgColor: const Color(0xFFE0F2FE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Cashback Amount',
                value: '₹${_balanceData.cashbackAmount.toStringAsFixed(2)}',
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFFDCFCE7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: _neumorphicCardDecoration(radius: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 3: Add Amount (Recharge Section in Neumorphic UI)
  Widget _buildAddAmountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _neumorphicCardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Add Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Instant recharge',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Top up your Khazana instantly and keep operations uninterrupted.',
            style: TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Input Row with Add Money Button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: _neumorphicSunkenDecoration(radius: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '₹',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: '100',
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Action Button
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C49F), Color(0xFF0072CE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C49F).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isRecharging ? null : _handleRecharge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRecharging
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Add Money',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          const Text(
            'Minimum recharge value is Rs. 100',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // 4 Quick Recharge Pills
          Row(
            children: [
              _buildQuickPill(100),
              const SizedBox(width: 6),
              _buildQuickPill(200),
              const SizedBox(width: 6),
              _buildQuickPill(500),
              const SizedBox(width: 6),
              _buildQuickPill(1000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPill(int amount) {
    final isSelected = _amountController.text == amount.toString();
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectQuickAmount(amount),
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD1FAE5) : const Color(0xFFEEF2F6),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        offset: const Offset(-2, -2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: const Color(0xFFCAD7E6).withValues(alpha: 0.6),
                        offset: const Offset(2, 2),
                        blurRadius: 3,
                      ),
                    ],
            ),
            child: Center(
              child: Text(
                '+ ₹$amount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF047857) : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Card 4: Communication Pricing Table (with Pull Refresh & Visible Table Refresh Action)
  Widget _buildCommunicationPricingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _neumorphicCardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Communication Pricing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'SMS, Email, WhatsApp Auth & Utility rates (Pull down to refresh)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Clearly visible Refresh Button on Table Header
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _loadWalletData();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E9F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: Color(0xFF051C48),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Clean Table with Rounded Outline matching POS Navy theme
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Table Header matching POS Header Theme
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    color: const Color(0xFF051C48),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Channel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Center(
                            child: Text(
                              'Credit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Price (₹)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Rows
                  for (int i = 0; i < _pricingItems.length; i++)
                    _buildPricingRow(_pricingItems[i], isLast: i == _pricingItems.length - 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(CommunicationPricingItem item, {required bool isLast}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
      child: Row(
        children: [
          // Icon in squircle badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: item.iconBgColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              item.icon,
              size: 14,
              color: item.iconColor,
            ),
          ),
          const SizedBox(width: 10),
          // Channel Title
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          // Credit
          SizedBox(
            width: 50,
            child: Center(
              child: Text(
                item.credit.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
          // Price
          SizedBox(
            width: 70,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                item.price,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card 5: Subtle Bottom Settings Tile for Wallet Rules
  Widget _buildWalletRulesTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openWalletSettingsModal,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _neumorphicCardDecoration(radius: 16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF059669), size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Rules & Cashback Settings',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Configure cashbacks, bonuses, negative khata balance',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
