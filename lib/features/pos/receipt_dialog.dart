import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/services/bluetooth_printer_service.dart';

class ReceiptDialog extends StatelessWidget {
  final OrderModel order;
  final String currency;

  const ReceiptDialog({
    super.key,
    required this.order,
    required this.currency,
  });

  String _formatAmount(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  void _shareBillReceipt(BuildContext context) {
    final db = DatabaseService();
    final rest = db.restaurant;
    final restName = rest?.name.isNotEmpty == true ? rest!.name : 'Apna POS Store';
    final restPhone = rest?.phone.isNotEmpty == true ? rest!.phone : '';
    final restAddress = rest?.address.isNotEmpty == true ? rest!.address : '';
    final gstNumber = rest?.gstNumber.isNotEmpty == true ? rest!.gstNumber : '';

    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('       ${restName.toUpperCase()}       ');
    if (restAddress.isNotEmpty) buffer.writeln(restAddress);
    if (restPhone.isNotEmpty) buffer.writeln('Mob: $restPhone');
    if (gstNumber.isNotEmpty) buffer.writeln('GST: #$gstNumber');
    buffer.writeln('================================');
    buffer.writeln('Bill No: #${order.orderNumber}');
    buffer.writeln('Invoice: #INV-${order.orderNumber}');
    buffer.writeln('Date: ${order.createdAt.isNotEmpty ? order.createdAt : DateTime.now().toString()}');
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buffer.writeln('Customer: ${order.customerName}');
    }
    if (order.orderType == OrderType.dineIn && order.tableNumber != null && order.tableNumber!.isNotEmpty) {
      buffer.writeln('Table: ${order.tableNumber}');
    }
    if (order.orderType == OrderType.delivery && order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) {
      buffer.writeln('Delivery Address:\n${order.deliveryAddress}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('ITEMS:');
    for (var item in order.items) {
      buffer.writeln(item.item.name);
      buffer.writeln('  Qty: ${item.quantity} x $currency${_formatAmount(item.item.price)} = $currency${_formatAmount(item.totalPrice)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Subtotal: $currency${_formatAmount(order.subtotal)}');
    if (order.discountAmount > 0) {
      buffer.writeln('Discount: -$currency${_formatAmount(order.discountAmount)}');
    }
    if (order.taxAmount > 0) {
      buffer.writeln('Tax (GST): $currency${_formatAmount(order.taxAmount)}');
    }
    if (order.tipAmount > 0) {
      buffer.writeln('Tip: +$currency${_formatAmount(order.tipAmount)}');
    }
    if (order.deliveryCharge > 0) {
      buffer.writeln('Delivery Charge: +$currency${_formatAmount(order.deliveryCharge)}');
    }
    if (order.roundOff.abs() > 0.001) {
      final sign = order.roundOff >= 0 ? '+' : '';
      buffer.writeln('Round Off: $sign$currency${_formatAmount(order.roundOff)}');
    }
    buffer.writeln('GRAND TOTAL: $currency${_formatAmount(order.totalAmount)}');
    buffer.writeln('Payment Method: ${order.paymentMethod}');
    buffer.writeln('================================');
    buffer.writeln('  Thank you! Visit Again!  ');
    buffer.writeln('   Powered by Apna POS    ');

    Share.share(
      buffer.toString(),
      subject: 'Bill Receipt #${order.orderNumber} - $restName',
    );
  }

  Widget _buildReceiptLogo(UserModel? user, RestaurantModel? rest) {
    final String photoPath = user?.profilePhotoPath ?? '';

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
              errorBuilder: (_, __, ___) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
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
                errorBuilder: (_, __, ___) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
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
              errorBuilder: (_, __, ___) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
            ),
          ),
        );
      } else {
        final file = File(photoPath);
        if (file.existsSync()) {
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
                errorBuilder: (_, __, ___) => _buildFallbackLogo(rest?.name ?? user?.companyName ?? 'POS'),
              ),
            ),
          );
        }
      }
    }

    // Do NOT show default Apna POS logo, show custom restaurant / business initials badge
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
          color: Color(0xFFD4AF37), // Gold accent
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final rest = db.restaurant;
    final user = db.currentUser;

    final String restName = rest?.name.isNotEmpty == true ? rest!.name : 'cafe de feasto';
    final String restAddress = rest?.address.isNotEmpty == true
        ? rest!.address
        : 'Dakshin Jagaddal, Narendrapur, Kolkata, West Bengal, India - 700149';
    final String restPhone = rest?.phone.isNotEmpty == true ? rest!.phone : '+91 7980614787';
    final String gstNumber = rest?.gstNumber.isNotEmpty == true ? rest!.gstNumber : '19FPYPD2539M1Z0';
    final double taxRate = rest?.taxRate ?? 5.0;
    final double cgstRate = taxRate / 2;
    final double sgstRate = taxRate / 2;
    final double cgstAmount = order.taxAmount / 2;
    final double sgstAmount = order.taxAmount / 2;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Flexible(
              child: Container(
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      width: 360,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      cartItem.item.name,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${cartItem.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF000000)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '$currency${_formatAmount(cartItem.item.price)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF000000)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '$currency${_formatAmount(cartItem.totalPrice)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          _buildReceiptRow('Sub Total', '$currency${_formatAmount(order.subtotal)}'),
                          if (order.discountAmount > 0) ...[
                            const SizedBox(height: 3),
                            _buildReceiptRow('Discount', '- $currency${_formatAmount(order.discountAmount)}'),
                          ],
                          if (order.taxAmount > 0) ...[
                            const SizedBox(height: 3),
                            _buildReceiptRow('CGST @ ${cgstRate.toStringAsFixed(1)}%', '$currency${_formatAmount(cgstAmount)}'),
                            const SizedBox(height: 3),
                            _buildReceiptRow('SGST @ ${sgstRate.toStringAsFixed(1)}%', '$currency${_formatAmount(sgstAmount)}'),
                          ],
                          if (order.tipAmount > 0) ...[
                            const SizedBox(height: 3),
                            _buildReceiptRow('Tip', '+ $currency${_formatAmount(order.tipAmount)}'),
                          ],
                          if (order.deliveryCharge > 0) ...[
                            const SizedBox(height: 3),
                            _buildReceiptRow('Delivery Charge', '+ $currency${_formatAmount(order.deliveryCharge)}'),
                          ],
                          if (order.roundOff.abs() > 0.001) ...[
                            const SizedBox(height: 3),
                            _buildReceiptRow(
                              'Round Off',
                              '${order.roundOff >= 0 ? '+' : ''}$currency${_formatAmount(order.roundOff)}',
                            ),
                          ],
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          _buildReceiptRow('Total Amount', '$currency${_formatAmount(order.totalAmount)}', isBold: true),
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          _buildReceiptRow('Payment Method', order.paymentMethod.toUpperCase(), isBold: true),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Payment Status',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                              ),
                              Builder(
                                builder: (_) {
                                  final bool isBillPaid = order.isPaid ||
                                      order.paymentStatus.toLowerCase() == 'paid' ||
                                      order.status == OrderStatus.completed;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isBillPaid
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isBillPaid
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFD97706),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      isBillPaid ? 'PAID (COMPLETED)' : 'UNPAID / RUNNING',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isBillPaid
                                            ? const Color(0xFF166534)
                                            : const Color(0xFF92400E),
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
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final printerService = BluetoothPrinterService();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Printing Thermal Bill via Bluetooth...'),
                              backgroundColor: Color(0xFF051C48),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        final dbInstance = DatabaseService();
                        final rest = dbInstance.restaurant;
                        final currentUser = dbInstance.currentUser;
                        final success = await printerService.printBill(
                          order: order,
                          restaurant: rest,
                          user: currentUser,
                          currency: currency,
                        );
                        if (!context.mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bill printed successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not print bill. Check Bluetooth printer power & connection.'),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                      label: const Text('Print Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareBillReceipt(context),
                      icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF051C48)),
                      label: const Text('Share Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF051C48))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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

  Widget _buildReceiptRow(String title, String val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 11.5 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: isBold ? 11.5 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicPaymentQrSection(BuildContext context) {
    final rest = DatabaseService().restaurant;
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
            'Amount: $currency${_formatAmount(order.totalAmount)}',
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
