import 'dart:async';
import 'dart:io' show File;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/windows_printer_service.dart';
import '../../core/services/ebill_service.dart';
import '../../core/services/order_service.dart';
import '../../core/services/network_service.dart';
import '../../core/widgets/printer_selection_dialog.dart';

enum EbillUiStatus {
  loading,
  ready,
  missingPhone,
  insufficientBalance,
  processing,
  sent,
  delivered,
  failed,
}

class ReceiptDialog extends StatefulWidget {
  final OrderModel order;
  final String currency;

  const ReceiptDialog({
    super.key,
    required this.order,
    required this.currency,
  });

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  late OrderModel _currentOrder;
  EbillUiStatus _ebillStatus = EbillUiStatus.loading;
  String _statusMessage = 'Checking eBill eligibility...';
  double _walletBalance = 0.0;
  double _ebillFee = 2.0;
  String? _activeEbillId;
  Timer? _pollingTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _checkEligibilityAndWallet();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _isDisposed = true;
    super.dispose();
  }

  String _formatAmount(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  /// Check business wallet balance and customer phone presence
  Future<void> _checkEligibilityAndWallet() async {
    final phone = (_currentOrder.customerPhone ?? '').trim();

    // 1. Check if customer phone number is missing
    if (phone.isEmpty) {
      if (mounted) {
        setState(() {
          _ebillStatus = EbillUiStatus.missingPhone;
          _statusMessage = "Please add the customer's mobile number to send the bill through WhatsApp.";
        });
      }
      // Load current wallet balance for informational display
      final balance = await EbillService().getWalletBalance();
      if (mounted && balance != null) {
        setState(() {
          _walletBalance = balance;
        });
      }
      return;
    }

    // 2. Fetch authoritative eligibility from backend if online
    if (NetworkService().isOnline) {
      final billId = _currentOrder.id.isNotEmpty ? _currentOrder.id : _currentOrder.orderNumber;
      final eligibility = await EbillService().checkEligibility(billId);
      if (!mounted) return;

      setState(() {
        _walletBalance = eligibility.walletBalance;
        _ebillFee = eligibility.ebillCharge;

        if (!eligibility.customerPhonePresent) {
          _ebillStatus = EbillUiStatus.missingPhone;
          _statusMessage = "Please add the customer's mobile number to send the bill through WhatsApp.";
        } else if (!eligibility.eligible && eligibility.reason == 'INSUFFICIENT_WALLET_BALANCE') {
          _ebillStatus = EbillUiStatus.insufficientBalance;
          _statusMessage = "Insufficient wallet balance. Please recharge your wallet to send the eBill.";
        } else {
          _ebillStatus = EbillUiStatus.ready;
          _statusMessage = "Ready to send via WhatsApp";
        }
      });
    } else {
      // Offline fallback: prompt that eBill requires network
      if (mounted) {
        setState(() {
          _ebillStatus = EbillUiStatus.ready;
          _statusMessage = "Offline mode. eBill will sync once connected.";
        });
      }
    }
  }

  /// Execute Save & eBill workflow
  Future<void> _handleSaveAndEbill() async {
    if (_ebillStatus == EbillUiStatus.processing) return;

    final phone = (_currentOrder.customerPhone ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add the customer's mobile number to send the bill through WhatsApp."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (!NetworkService().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("eBill requires an active internet connection. Bill is safely stored locally."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _ebillStatus = EbillUiStatus.processing;
      _statusMessage = "Saving bill & sending eBill via WhatsApp...";
    });

    try {
      // 1. Ensure bill is persisted to database if not already saved/synced
      OrderModel finalOrder = _currentOrder;
      if (!_currentOrder.isSynced || _currentOrder.id.isEmpty) {
        try {
          finalOrder = await OrderService().createOrder(_currentOrder);
          _currentOrder = finalOrder;
        } catch (saveErr) {
          debugPrint('[ReceiptDialog] Note on order creation: $saveErr');
        }
      }

      final billId = finalOrder.id.isNotEmpty ? finalOrder.id : finalOrder.orderNumber;

      // 2. Submit eBill send request to backend
      final result = await EbillService().sendEbill(
        billId: billId,
        customerId: finalOrder.customerId,
        customerPhone: phone,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _activeEbillId = result.ebillId;
          _walletBalance = result.walletBalance;
          _ebillStatus = EbillUiStatus.sent;
          _statusMessage = "WhatsApp Status: Sent to customer";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✓ eBill sent successfully to $phone!"),
            backgroundColor: const Color(0xFF166534),
            duration: const Duration(seconds: 2),
          ),
        );

        // 3. Briefly poll webhook status for live delivery confirmation (DELIVERED)
        _startDeliveryPolling(result.ebillId);
      } else {
        setState(() {
          _ebillStatus = EbillUiStatus.failed;
          _statusMessage = "Bill saved, but WhatsApp delivery failed. Please retry.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final cleanError = e.toString().replaceAll('Exception:', '').trim();
      setState(() {
        _ebillStatus = EbillUiStatus.failed;
        _statusMessage = "Bill saved, but WhatsApp delivery failed. Please retry.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("WhatsApp Delivery Alert: $cleanError"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Poll eBill delivery status from WhatsApp webhook updates
  void _startDeliveryPolling(String? ebillId) {
    if (ebillId == null || ebillId.isEmpty) return;
    _pollingTimer?.cancel();
    int pollAttempts = 0;

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      pollAttempts++;
      if (pollAttempts > 10 || _isDisposed) {
        timer.cancel();
        return;
      }

      final statusData = await EbillService().getStatus(ebillId);
      if (!mounted || statusData == null) return;

      final deliveryStatus = (statusData['deliveryStatus'] ?? '').toString().toUpperCase();
      if (deliveryStatus == 'DELIVERED') {
        setState(() {
          _ebillStatus = EbillUiStatus.delivered;
          _statusMessage = "WhatsApp Status: Delivered to customer";
        });
        timer.cancel();
      } else if (deliveryStatus == 'FAILED') {
        setState(() {
          _ebillStatus = EbillUiStatus.failed;
          _statusMessage = "Bill saved, but WhatsApp delivery failed. Please retry.";
        });
        timer.cancel();
      }
    });
  }

  bool get _isSaveAndEbillEnabled {
    final phone = (_currentOrder.customerPhone ?? '').trim();
    if (phone.isEmpty) return false;
    if (_ebillStatus == EbillUiStatus.insufficientBalance) return false;
    if (_ebillStatus == EbillUiStatus.processing) return false;
    return true;
  }

  Widget _buildReceiptLogo(UserModel? user, RestaurantModel? rest) {
    final String photoPath = DatabaseService().companyLogoPath ?? user?.profilePhotoPath ?? '';

    if (photoPath.isNotEmpty) {
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        return Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF051C48), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: ClipOval(
            child: Image.network(
              photoPath,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
            ),
          ),
        );
      } else if (photoPath.startsWith('data:image') || (photoPath.length > 50 && !photoPath.startsWith('/'))) {
        try {
          final cleanBase64 = photoPath.contains(',') ? photoPath.split(',').last : photoPath;
          final bytes = base64Decode(cleanBase64);
          return Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF051C48), width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: ClipOval(
              child: Image.memory(
                bytes,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
              ),
            ),
          );
        } catch (_) {}
      } else if (photoPath.startsWith('assets/')) {
        return Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF051C48), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: ClipOval(
            child: Image.asset(
              photoPath,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
            ),
          ),
        );
      } else if (!kIsWeb && File(photoPath).existsSync()) {
        final file = File(photoPath);
        return Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF051C48), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: ClipOval(
            child: Image.file(
              file,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
            ),
          ),
        );
      }
    }

    return _buildFallbackLogo(rest?.name ?? user?.companyName ?? user?.name ?? 'POS');
  }

  Widget _buildFallbackLogo(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    final String initials = words.length > 1
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : (name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase());

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF051C48),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : 'POS',
        style: const TextStyle(
          color: Color(0xFFD4AF37),
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// eBill and Business Wallet Summary Card
  Widget _buildEbillWalletSummaryCard() {
    final phone = (_currentOrder.customerPhone ?? '').trim();
    final remainingBalance = (_walletBalance - _ebillFee).clamp(0.0, double.infinity);

    Color statusBadgeColor;
    Color statusTextColor;
    IconData statusIcon;

    switch (_ebillStatus) {
      case EbillUiStatus.ready:
        statusBadgeColor = const Color(0xFFEFF6FF);
        statusTextColor = const Color(0xFF1D4ED8);
        statusIcon = Icons.mark_chat_read_rounded;
        break;
      case EbillUiStatus.missingPhone:
        statusBadgeColor = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFF92400E);
        statusIcon = Icons.phone_missed_rounded;
        break;
      case EbillUiStatus.insufficientBalance:
        statusBadgeColor = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFF991B1B);
        statusIcon = Icons.account_balance_wallet_outlined;
        break;
      case EbillUiStatus.processing:
        statusBadgeColor = const Color(0xFFE0F2FE);
        statusTextColor = const Color(0xFF0369A1);
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case EbillUiStatus.sent:
        statusBadgeColor = const Color(0xFFECFDF5);
        statusTextColor = const Color(0xFF047857);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case EbillUiStatus.delivered:
        statusBadgeColor = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
        statusIcon = Icons.done_all_rounded;
        break;
      case EbillUiStatus.failed:
        statusBadgeColor = const Color(0xFFFEF2F2);
        statusTextColor = const Color(0xFFB91C1C);
        statusIcon = Icons.error_outline_rounded;
        break;
      case EbillUiStatus.loading:
        statusBadgeColor = const Color(0xFFF1F5F9);
        statusTextColor = const Color(0xFF475569);
        statusIcon = Icons.sync_rounded;
        break;
    }


    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF051C48)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Business Wallet: ${widget.currency}${_formatAmount(_walletBalance)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF051C48),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'eBill Fee: ${widget.currency}${_formatAmount(_ebillFee)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3730A3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Balance After: ${widget.currency}${_formatAmount(remainingBalance)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (phone.isNotEmpty)
                Text(
                  'Mobile: $phone',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
            ],
          ),

          if (_activeEbillId != null && _activeEbillId!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'eBill Ref: #$_activeEbillId',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Dynamic WhatsApp Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusBadgeColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusTextColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                if (_ebillStatus == EbillUiStatus.processing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0369A1)),
                  )
                else
                  Icon(statusIcon, size: 15, color: statusTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusTextColor,
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

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final rest = db.restaurant;
    final user = db.currentUser;
    final order = _currentOrder;

    final String restName = rest?.name.isNotEmpty == true ? rest!.name : 'cafe de feasto';
    final String restAddress = rest?.address.isNotEmpty == true
        ? rest!.address
        : 'Dakshin Jagaddal, Narendrapur, Kolkata, West Bengal, India - 700149';
    final String restPhone = rest?.phone.isNotEmpty == true ? rest!.phone : '+91 7980614787';
    final String gstNumber = rest?.gstNumber.isNotEmpty == true ? rest!.gstNumber : '19FPYPD2539M1Z0';
    final double cgstAmount = order.taxAmount / 2;
    final double sgstAmount = order.taxAmount / 2;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF051C48),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Thermal Bill Preview',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            // Body: Thermal bill scrollable view
            Flexible(
              child: Container(
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      width: 360,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildReceiptLogo(user, rest),
                          const SizedBox(height: 10),
                          Text(
                            restName.toLowerCase(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF000000),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            restAddress,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E293B), height: 1.3),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mob: $restPhone',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            order.orderType == OrderType.dineIn
                                ? 'DineIn'
                                : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                          ),
                          if (order.orderType == OrderType.dineIn && order.tableNumber != null && order.tableNumber!.isNotEmpty)
                            Text(
                              'Dine In - Table ${order.tableNumber!.replaceAll('T-', '')}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            ),
                          if (order.orderType == OrderType.delivery && order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF94A3B8), width: 0.8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DELIVERY ADDRESS:',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.deliveryAddress!,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000), height: 1.25),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          if (order.customerName != null && order.customerName!.isNotEmpty)
                            Text(
                              'Customer Name: ${order.customerName!.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            ),
                          if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                            Text(
                              'Customer Mobile: ${order.customerPhone}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            order.createdAt.isNotEmpty ? order.createdAt : '07/08/2026 09:20:58 PM',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                          ),
                          const SizedBox(height: 6),
                          Text('Bill: #${order.orderNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                          Text('Invoice: #INV-${order.orderNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000))),
                          Text('Order No: #${order.id.isNotEmpty ? order.id : order.orderNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF000000))),
                          Text('GST: #$gstNumber', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                          const SizedBox(height: 6),
                          Text('Pay To : $restName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                          const SizedBox(height: 8),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Expanded(flex: 3, child: Text('ITEM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)))),
                              Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)))),
                              Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)))),
                              Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          ...order.items.map((cartItem) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      cartItem.item.name,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${cartItem.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${widget.currency}${_formatAmount(cartItem.item.effectivePrice > 0 ? cartItem.item.effectivePrice : cartItem.item.price)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${widget.currency}${_formatAmount(cartItem.totalPrice)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          _buildReceiptRow('Sub Total :', '${widget.currency}${_formatAmount(order.subtotal)}'),
                          if (order.discountAmount > 0)
                            _buildReceiptRow('Discount :', '-${widget.currency}${_formatAmount(order.discountAmount)}', textColor: Colors.green),
                          if (order.taxAmount > 0) ...[
                            _buildReceiptRow('CGST (2.5%) :', '${widget.currency}${_formatAmount(cgstAmount)}'),
                            _buildReceiptRow('SGST (2.5%) :', '${widget.currency}${_formatAmount(sgstAmount)}'),
                          ],
                          if (order.tipAmount > 0)
                            _buildReceiptRow('Tip :', '+${widget.currency}${_formatAmount(order.tipAmount)}'),
                          if (order.deliveryCharge > 0)
                            _buildReceiptRow('Delivery Charge :', '+${widget.currency}${_formatAmount(order.deliveryCharge)}'),
                          if (order.roundOff.abs() > 0.001)
                            _buildReceiptRow('Round Off :', '${order.roundOff >= 0 ? "+" : ""}${widget.currency}${_formatAmount(order.roundOff)}'),
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          _buildReceiptRow('Total :', '${widget.currency}${_formatAmount(order.totalAmount)}', isBold: true),
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Payment: ${order.paymentMethod}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Builder(
                                builder: (_) {
                                  final bool isBillPaid = order.isPaid ||
                                      order.paymentStatus.toLowerCase() == 'paid' ||
                                      order.status == OrderStatus.completed;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isBillPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isBillPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      isBillPaid ? 'PAID (COMPLETED)' : 'UNPAID / RUNNING',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isBillPaid ? const Color(0xFF166534) : const Color(0xFF92400E),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          if (order.printCount > 0) ...[
                            const SizedBox(height: 3),
                            _buildReceiptRow('Print Version', '#${order.printCount}'),
                          ],
                          const SizedBox(height: 8),
                          _buildCenterLine(),
                          const SizedBox(height: 6),
                          // Dynamic Payment QR Code Section
                          _buildDynamicPaymentQrSection(context),
                          const SizedBox(height: 6),
                          _buildCenterLine(),
                          const SizedBox(height: 8),
                          const Text(
                            'Thank you! Visit Again!',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Powered by Apna POS',
                            style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom Action Bar with eBill Summary and Actions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Business Wallet & eBill Status Section
                  _buildEbillWalletSummaryCard(),
                  const SizedBox(height: 12),
                  // Action Buttons: Print Thermal + Save & eBill
                  Row(
                    children: [
                      // Print Thermal Button (unchanged)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final printerService = BluetoothPrinterService();
                            final dbInstance = DatabaseService();
                            final rest = dbInstance.restaurant;
                            final currentUser = dbInstance.currentUser;

                            // 1. Windows Native / Bluetooth Flow
                            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
                              final windowsService = WindowsPrinterService();
                              final printers = await windowsService.getInstalledPrinters();
                              final activeDefault = await windowsService.getActiveDefaultPrinter();

                              if (printers.isEmpty) {
                                if (context.mounted) {
                                  PrinterSelectionDialog.show(context, orderToPrint: order, currency: widget.currency);
                                }
                                return;
                              }

                              if (printers.length == 1 || (activeDefault != null && windowsService.cachedSavedPrinterName != null)) {
                                final target = activeDefault ?? printers.first;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Printing to ${target.name}...'),
                                      backgroundColor: const Color(0xFF051C48),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                                final success = await printerService.printBill(
                                  order: order,
                                  restaurant: rest,
                                  user: currentUser,
                                  currency: widget.currency,
                                  windowsPrinter: target,
                                );
                                if (!context.mounted) return;
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Bill printed successfully on ${target.name}!'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  PrinterSelectionDialog.show(context, orderToPrint: order, currency: widget.currency);
                                }
                                return;
                              }

                              if (context.mounted) {
                                PrinterSelectionDialog.show(context, orderToPrint: order, currency: widget.currency);
                              }
                              return;
                            }

                            // 2. Mobile Android / iOS Bluetooth Flow
                            bool isConn = await printerService.isConnected();
                            if (!isConn) {
                              isConn = await printerService.autoConnectSavedPrinter();
                            }

                            if (isConn) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Printing Thermal Bill...'),
                                    backgroundColor: Color(0xFF051C48),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                              final success = await printerService.printBill(
                                order: order,
                                restaurant: rest,
                                user: currentUser,
                                currency: widget.currency,
                              );
                              if (!context.mounted) return;
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bill printed successfully!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                PrinterSelectionDialog.show(context, orderToPrint: order, currency: widget.currency);
                              }
                            } else if (context.mounted) {
                              PrinterSelectionDialog.show(context, orderToPrint: order, currency: widget.currency);
                            }
                          },
                          icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            'Print Thermal',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF051C48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Save & eBill Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaveAndEbillEnabled ? _handleSaveAndEbill : null,
                          icon: _ebillStatus == EbillUiStatus.processing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          label: Text(
                            _ebillStatus == EbillUiStatus.processing ? 'Sending...' : 'Save & eBill',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // WhatsApp brand green
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: _isSaveAndEbillEnabled ? 2 : 0,
                          ),
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
    );
  }

  Widget _buildDashedLine() {
    return const SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(
        painter: _DashedLinePainter(),
      ),
    );
  }

  Widget _buildCenterLine() {
    return Center(
      child: Container(
        width: 160,
        height: 1,
        color: const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildReceiptRow(String title, String val, {bool isBold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 11.5 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: textColor ?? const Color(0xFF000000),
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: isBold ? 11.5 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: textColor ?? const Color(0xFF000000),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicPaymentQrSection(BuildContext context) {
    final rest = DatabaseService().restaurant;
    final order = _currentOrder;
    final String upiId = (rest?.upiId ?? '').trim();
    final String qrPayload = (order.qrIntentUrl != null && order.qrIntentUrl!.isNotEmpty)
        ? order.qrIntentUrl!
        : (upiId.isNotEmpty
            ? 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(rest?.name ?? "Apna POS")}&am=${order.totalAmount.toStringAsFixed(2)}&cu=INR&tr=${order.orderNumber}&tn=${Uri.encodeComponent("Bill ${order.orderNumber}")}'
            : 'upi://pay?pa=apnapos@upi&pn=${Uri.encodeComponent(rest?.name ?? "Apna POS")}&am=${order.totalAmount.toStringAsFixed(2)}&cu=INR&tr=${order.orderNumber}&tn=${Uri.encodeComponent("Bill ${order.orderNumber}")}');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        children: [
          Text(
            order.isPaid ? 'PAYMENT QR (UPI)' : 'SCAN & PAY WITH ANY UPI APP',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Color(0xFF051C48),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 110.0,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Amount: ${widget.currency}${_formatAmount(order.totalAmount)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          if (upiId.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'UPI ID: $upiId',
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.0;

    const double dashWidth = 4.0;
    const double dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset((startX + dashWidth).clamp(0, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
