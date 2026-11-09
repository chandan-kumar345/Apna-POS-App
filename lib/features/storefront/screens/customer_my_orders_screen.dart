import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/restaurant_model.dart';
import '../models/customer_storefront_flow_models.dart';
import '../services/customer_storefront_api_service.dart';

class CustomerMyOrdersScreen extends StatefulWidget {
  final CustomerOrderTrackingModel order;
  final RestaurantModel? restaurant;
  final String? tableCode;
  final Color themeColor;

  const CustomerMyOrdersScreen({
    super.key,
    required this.order,
    this.restaurant,
    this.tableCode,
    this.themeColor = const Color(0xFF065F46),
  });

  @override
  State<CustomerMyOrdersScreen> createState() => _CustomerMyOrdersScreenState();
}

class _CustomerMyOrdersScreenState extends State<CustomerMyOrdersScreen> {
  late CustomerOrderTrackingModel _currentOrder;
  final CustomerStorefrontApiService _apiService = CustomerStorefrontApiService();
  StreamSubscription<CustomerOrderTrackingModel?>? _orderStreamSub;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _subscribeToOrderUpdates();
  }

  void _subscribeToOrderUpdates() {
    _orderStreamSub = _apiService.streamOrderStatus(_currentOrder.orderId).listen((updated) {
      if (updated != null && mounted) {
        setState(() {
          _currentOrder = updated;
        });
      }
    });
  }

  @override
  void dispose() {
    _orderStreamSub?.cancel();
    super.dispose();
  }

  String get _displayTable {
    if (widget.tableCode != null && widget.tableCode!.trim().isNotEmpty) {
      return widget.tableCode!.trim();
    }
    if (_currentOrder.deliveryAddress.toLowerCase().contains('table')) {
      final parts = _currentOrder.deliveryAddress.split(' ');
      if (parts.length > 1) return parts.last;
    }
    return '01';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  Color get _statusColor {
    switch (_currentOrder.currentStepIndex) {
      case 0:
        return const Color(0xFF0284C7); // Sky blue
      case 1:
        return const Color(0xFFD97706); // Amber
      case 2:
        return const Color(0xFF16A34A); // Emerald green
      case 3:
        return const Color(0xFF059669); // Forest green
      default:
        return widget.themeColor;
    }
  }

  String get _statusLabel {
    switch (_currentOrder.currentStepIndex) {
      case 0:
        return 'Order Confirmed';
      case 1:
        return 'Cooking in Kitchen';
      case 2:
        return 'Ready to Serve';
      case 3:
        return 'Served at Table';
      default:
        return _currentOrder.status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.themeColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Clean neumorphic background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Orders',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live Kitchen Tracking • Table $_displayTable',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Order ID',
            icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentOrder.orderNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order ID copied: ${_currentOrder.orderNumber}'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Order Status Hero Card
              _buildHeroStatusCard(themeColor),

              const SizedBox(height: 16),

              // 2. Kitchen Progress Timeline
              _buildKitchenTimelineCard(themeColor),

              const SizedBox(height: 16),

              // 3. Ordered Food Items Breakdown
              _buildItemsBreakdownCard(),

              const SizedBox(height: 16),

              // 4. Bill & Payment Summary Card
              _buildBillSummaryCard(),

              const SizedBox(height: 20),

              // 5. Action Buttons (Order More Items / Call Waiter)
              _buildActionButtons(themeColor),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatusCard(Color themeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-2, -2),
            blurRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            offset: const Offset(2, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentOrder.orderNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Placed at ${_formatTime(_currentOrder.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              _buildPillTag(Icons.table_restaurant_rounded, 'Table $_displayTable', const Color(0xFF047857), const Color(0xFFD1FAE5)),
              const SizedBox(width: 8),
              _buildPillTag(Icons.timer_outlined, 'Est: ${_currentOrder.estimatedDeliveryMinutes}', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
              const SizedBox(width: 8),
              _buildPillTag(Icons.restaurant_rounded, '${_currentOrder.items.length} Items', const Color(0xFF4338CA), const Color(0xFFEEF2FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillTag(IconData icon, String label, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenTimelineCard(Color themeColor) {
    final stepIdx = _currentOrder.currentStepIndex;

    final steps = [
      {
        'title': 'Order Placed & Confirmed',
        'subtitle': 'Sent to kitchen display & accepted',
        'icon': Icons.check_circle_rounded,
      },
      {
        'title': 'Cooking in Kitchen',
        'subtitle': 'Chef is preparing your fresh meal',
        'icon': Icons.outdoor_grill_rounded,
      },
      {
        'title': 'Ready to Serve',
        'subtitle': 'Food plated and waiting for waiter',
        'icon': Icons.room_service_rounded,
      },
      {
        'title': 'Served at Table $_displayTable',
        'subtitle': 'Enjoy your meal! Let us know if you need anything',
        'icon': Icons.dining_rounded,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-2, -2),
            blurRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            offset: const Offset(2, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timeline_rounded, size: 16, color: themeColor),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Kitchen Preparation Timeline',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++) ...[
            _buildTimelineStepRow(
              title: steps[i]['title'] as String,
              subtitle: steps[i]['subtitle'] as String,
              icon: steps[i]['icon'] as IconData,
              isCompleted: stepIdx > i,
              isCurrent: stepIdx == i,
              isLast: i == steps.length - 1,
              themeColor: themeColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineStepRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required Color themeColor,
  }) {
    final Color stepColor = isCompleted
        ? const Color(0xFF10B981)
        : (isCurrent ? themeColor : const Color(0xFFCBD5E1));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF10B981)
                    : (isCurrent ? themeColor.withValues(alpha: 0.15) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: stepColor,
                  width: isCurrent ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  size: 14,
                  color: isCompleted ? Colors.white : (isCurrent ? themeColor : const Color(0xFF94A3B8)),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent || isCompleted ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent || isCompleted ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrent ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-2, -2),
            blurRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            offset: const Offset(2, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _currentOrder.items.length; i++) ...[
            _buildOrderItemRow(_currentOrder.items[i]),
            if (i < _currentOrder.items.length - 1)
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(CustomerOrderItemSummary item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      softWrap: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (item.size.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.size,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  softWrap: true,
                ),
              ],
              if (item.addons.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Add-ons: ${item.addons.join(", ")}',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF0284C7)),
                  softWrap: true,
                ),
              ],
              if (item.instructions != null && item.instructions!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Note: ${item.instructions}',
                  style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                  softWrap: true,
                ),
              ],
              const SizedBox(height: 2),
              Text(
                'Qty: ${item.quantity}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-2, -2),
            blurRadius: 5,
          ),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            offset: const Offset(2, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildBillRow('Item Total', '₹${_currentOrder.subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          _buildBillRow('Taxes & GST', '₹${_currentOrder.tax.toStringAsFixed(0)}'),
          if (_currentOrder.discount > 0) ...[
            const SizedBox(height: 6),
            _buildBillRow('Discount', '-₹${_currentOrder.discount.toStringAsFixed(0)}', isGreen: true),
          ],
          const SizedBox(height: 6),
          _buildBillRow('Dining Table Service', 'FREE', isGreen: true),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              Text(
                '₹${_currentOrder.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Payment: ${_currentOrder.paymentMethod} (${_currentOrder.paymentStatus})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isGreen ? const Color(0xFF059669) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color themeColor) {
    return Column(
      children: [
        // Primary: Order More Items
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Order More Items',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Secondary: Call Waiter / Call Outlet
        if (widget.restaurant?.phone != null && widget.restaurant!.phone.trim().isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                final phoneClean = widget.restaurant!.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                launchUrl(Uri.parse('tel:$phoneClean'));
              },
              icon: Icon(Icons.call_rounded, size: 16, color: themeColor),
              label: Text(
                'Need Help? Call Outlet (${widget.restaurant!.phone})',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: themeColor),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: themeColor.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }
}
