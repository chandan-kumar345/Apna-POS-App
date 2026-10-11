import 'dart:async';
import 'dart:io' show File;
import 'dart:convert';
import 'dart:math' as math;
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

  void _showInsufficientBalanceSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _walletBalance > 0
                    ? 'Insufficient wallet balance (${widget.currency}${_formatAmount(_walletBalance)}). Please recharge your wallet to send eBill.'
                    : 'Insufficient wallet balance to send eBill. Please recharge your business wallet.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Check business wallet balance and customer phone presence
  Future<void> _checkEligibilityAndWallet() async {
    final phone = (_currentOrder.customerPhone ?? '').trim();

    // 1. If customer phone number is missing, just load wallet balance
    if (phone.isEmpty) {
      if (mounted) {
        setState(() {
          _ebillStatus = EbillUiStatus.missingPhone;
        });
      }
      try {
        final balance = await EbillService().getWalletBalance();
        if (mounted && balance != null) {
          setState(() {
            _walletBalance = balance;
          });
        }
      } catch (_) {}
      return;
    }

    // 2. Customer phone is present - checkEligibility returns authoritative wallet balance + fee in 1 call
    if (NetworkService().isOnline) {
      final billId = _currentOrder.id.isNotEmpty ? _currentOrder.id : _currentOrder.orderNumber;
      try {
        final eligibility = await EbillService().checkEligibility(billId);
        if (!mounted) return;

        setState(() {
          _walletBalance = eligibility.walletBalance;
          _ebillFee = eligibility.ebillCharge;

          if (!eligibility.customerPhonePresent) {
            _ebillStatus = EbillUiStatus.missingPhone;
          } else if (!eligibility.eligible && eligibility.reason == 'INSUFFICIENT_WALLET_BALANCE') {
            _ebillStatus = EbillUiStatus.insufficientBalance;
          } else {
            _ebillStatus = EbillUiStatus.ready;
          }
        });

        if (!eligibility.eligible && eligibility.reason == 'INSUFFICIENT_WALLET_BALANCE') {
          _showInsufficientBalanceSnackbar();
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _ebillStatus = EbillUiStatus.ready;
          });
        }
      }
    } else {
      // Offline fallback: prompt that eBill requires network
      if (mounted) {
        setState(() {
          _ebillStatus = EbillUiStatus.ready;
        });
      }
    }
  }

  /// Execute Save & eBill workflow
  Future<void> _handleSaveAndEbill() async {
    if (_ebillStatus == EbillUiStatus.processing) return;

    final phone = (_currentOrder.customerPhone ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.phone_missed_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Please add the customer's mobile number to send the bill through WhatsApp.",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_ebillStatus == EbillUiStatus.insufficientBalance ||
        (_walletBalance > 0 && _walletBalance < _ebillFee)) {
      _showInsufficientBalanceSnackbar();
      return;
    }

    if (!NetworkService().isOnline) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "eBill requires an active internet connection. Bill is safely stored locally.",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _ebillStatus = EbillUiStatus.processing;
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
        });

        final refText = _activeEbillId != null && _activeEbillId!.isNotEmpty
            ? " (Ref: #$_activeEbillId)"
            : "";
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "WhatsApp eBill Sent Successfully!",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Bill #${finalOrder.orderNumber} delivered to $phone$refText",
                        style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12, color: Color(0xFFD1FAE5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );

        // 3. Briefly poll webhook status for live delivery confirmation (DELIVERED)
        _startDeliveryPolling(result.ebillId);
      } else {
        final isBalanceError = result.message.toLowerCase().contains('balance') ||
            result.message.toLowerCase().contains('wallet');
        setState(() {
          _ebillStatus = isBalanceError ? EbillUiStatus.insufficientBalance : EbillUiStatus.failed;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isBalanceError ? Icons.account_balance_wallet_outlined : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBalanceError
                        ? "Insufficient wallet balance to send eBill. Please recharge your wallet."
                        : result.message,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: isBalanceError ? const Color(0xFFDC2626) : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final cleanError = e.toString().replaceAll('Exception:', '').trim();
      final isBalanceError = cleanError.toLowerCase().contains('balance') ||
          cleanError.toLowerCase().contains('wallet');
      setState(() {
        _ebillStatus = isBalanceError ? EbillUiStatus.insufficientBalance : EbillUiStatus.failed;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isBalanceError ? Icons.account_balance_wallet_outlined : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isBalanceError
                      ? "Insufficient wallet balance to send eBill. Please recharge your wallet."
                      : "WhatsApp Delivery Alert: $cleanError",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: isBalanceError ? const Color(0xFFDC2626) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
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
        });
        timer.cancel();
      } else if (deliveryStatus == 'FAILED') {
        setState(() {
          _ebillStatus = EbillUiStatus.failed;
        });
        timer.cancel();
      }
    });
  }

  bool get _isSaveAndEbillEnabled {
    return _ebillStatus != EbillUiStatus.processing;
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

  Widget _buildDialogHeader(BuildContext context, OrderModel order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF051C48),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Thermal Bill Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.orderNumber.isNotEmpty)
                        Text(
                          '#${order.orderNumber}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white.withValues(alpha: 0.15),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThermalPaperReceipt({
    required BuildContext context,
    required OrderModel order,
    required UserModel? user,
    required RestaurantModel? rest,
    required String restName,
    required String restAddress,
    required String restPhone,
    required String gstNumber,
    required double cgstAmount,
    required double sgstAmount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Store Logo
          _buildReceiptLogo(user, rest),
          const SizedBox(height: 10),

          // Restaurant Name (Uppercase, bold, receipt style)
          Text(
            restName.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF000000),
              letterSpacing: 0.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),

          // Address & Mob
          Text(
            restAddress,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'Mob: $restPhone',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Order Type & Table
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              order.orderType == OrderType.dineIn
                  ? (order.tableNumber != null && order.tableNumber!.isNotEmpty
                      ? 'Dine In - Table ${order.tableNumber!.replaceAll('T-', '')}'
                      : 'DineIn')
                  : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Delivery Address if delivery
          if (order.orderType == OrderType.delivery && order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DELIVERY ADDRESS:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.deliveryAddress!,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF1E293B), height: 1.25),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),

          // Customer details
          if (order.customerName != null && order.customerName!.isNotEmpty)
            Text(
              'Customer Name: ${order.customerName!.toUpperCase()}',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
            ),
          if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
            Text(
              'Customer Mobile: ${order.customerPhone}',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
            ),
          const SizedBox(height: 4),

          // Bill Metadata
          Text(
            order.createdAt.isNotEmpty ? order.createdAt : '07/08/2026 09:20:58 PM',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
          ),
          const SizedBox(height: 4),
          Text('Bill: #${order.orderNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
          Text('Invoice: #INV-${order.orderNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000))),
          Text('Order No: #${order.id.isNotEmpty ? order.id : order.orderNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF334155))),
          Text('GST: #$gstNumber', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
          const SizedBox(height: 4),
          Text('Pay To : $restName', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
          const SizedBox(height: 8),

          _buildDashedLine(),
          const SizedBox(height: 5),

          // Table Header
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
          const SizedBox(height: 5),

          // Items List
          ...order.items.map((cartItem) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 5),
          _buildDashedLine(),
          const SizedBox(height: 6),

          // Calculations Breakdown
          _buildReceiptRow('Sub Total :', '${widget.currency}${_formatAmount(order.subtotal)}'),
          if (order.discountAmount > 0)
            _buildReceiptRow('Discount :', '-${widget.currency}${_formatAmount(order.discountAmount)}', textColor: const Color(0xFF16A34A)),
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

          // Grand Total
          _buildReceiptRow('Total :', '${widget.currency}${_formatAmount(order.totalAmount)}', isBold: true, fontSize: 13),
          const SizedBox(height: 6),
          _buildDashedLine(),
          const SizedBox(height: 6),

          // Payment Status
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                        fontSize: 9.5,
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

          // Dynamic QR Code Section
          _buildDynamicPaymentQrSection(context),
          const SizedBox(height: 6),
          _buildCenterLine(),
          const SizedBox(height: 8),

          // Thank you footer
          const Text(
            'Thank you! Visit Again!',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          const Text(
            'Powered by Apna POS',
            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    OrderModel order,
    RestaurantModel? rest,
    UserModel? currentUser,
  ) {
    final isProcessing = _ebillStatus == EbillUiStatus.processing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Print Thermal Button
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _handlePrintThermal(context, order, rest, currentUser),
                icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Print Thermal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48),
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Save & eBill Button
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSaveAndEbillEnabled ? _handleSaveAndEbill : null,
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isProcessing ? 'Sending...' : 'Save & eBill',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp brand green
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF86EFAC),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePrintThermal(
    BuildContext context,
    OrderModel order,
    RestaurantModel? rest,
    UserModel? currentUser,
  ) async {
    final printerService = BluetoothPrinterService();
    final dbInstance = DatabaseService();
    final currentRest = rest ?? dbInstance.restaurant;
    final user = currentUser ?? dbInstance.currentUser;

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
          restaurant: currentRest,
          user: user,
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
        restaurant: currentRest,
        user: user,
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
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final rest = db.restaurant;
    final user = db.currentUser;
    final order = _currentOrder;

    final String restName = rest?.name.isNotEmpty == true ? rest!.name : 'Cafe De Feasto';
    final String restAddress = rest?.address.isNotEmpty == true
        ? rest!.address
        : 'Dakshin Jagaddal, Narendrapur, Kolkata, West Bengal, India - 700149';
    final String restPhone = rest?.phone.isNotEmpty == true ? rest!.phone : '+91 7980614787';
    final String gstNumber = rest?.gstNumber.isNotEmpty == true ? rest!.gstNumber : '19FPYPD2539M1Z0';
    final double cgstAmount = order.taxAmount / 2;
    final double sgstAmount = order.taxAmount / 2;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isSmallPhone = screenSize.width < 380;
    final isLandscape = screenSize.width > screenSize.height;

    // Responsive dialog constraints across all device types
    final double dialogMaxWidth = screenSize.width < 500
        ? math.max(280.0, screenSize.width - (isSmallPhone ? 16.0 : 28.0))
        : 440.0;

    final double dialogMaxHeight = isLandscape
        ? screenSize.height * 0.94
        : math.min(screenSize.height * 0.90, 860.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallPhone ? 8.0 : 16.0,
        vertical: isSmallPhone ? 10.0 : 18.0,
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: dialogMaxHeight,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38000000),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Sleek Modern Header
                  _buildDialogHeader(context, order),

                  // 2. Body: Responsive Thermal Bill Slip in ScrollView
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double maxPaperWidth = math.min(
                          360.0,
                          constraints.maxWidth - (isSmallPhone ? 12.0 : 24.0),
                        );
                        return Container(
                          width: double.infinity,
                          color: const Color(0xFFF1F5F9),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallPhone ? 6 : 14,
                              vertical: 14,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxPaperWidth,
                                ),
                                child: _buildThermalPaperReceipt(
                                  context: context,
                                  order: order,
                                  user: user,
                                  rest: rest,
                                  restName: restName,
                                  restAddress: restAddress,
                                  restPhone: restPhone,
                                  gstNumber: gstNumber,
                                  cgstAmount: cgstAmount,
                                  sgstAmount: sgstAmount,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 3. Redesigned Clean Bottom Action Bar
                  _buildBottomActionBar(context, order, rest, user),
                ],
              ),
            ),
          ),
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

  Widget _buildReceiptRow(String title, String val, {bool isBold = false, Color? textColor, double? fontSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize ?? (isBold ? 11.5 : 10.5),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: textColor ?? const Color(0xFF000000),
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: fontSize ?? (isBold ? 11.5 : 10.5),
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
