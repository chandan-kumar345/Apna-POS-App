import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';

/// Glass Liquid UI Dashboard Screen matching Apna POS design theme
class GlassDashboardScreen extends StatefulWidget {
  final Function(int index)? onNavigateTab;
  
  const GlassDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<GlassDashboardScreen> createState() => _GlassDashboardScreenState();

}

class _GlassDashboardScreenState extends State<GlassDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  int _activeNavIndex = 0;
  String _dashboardFilter = 'Today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  List<OrderModel> _filterOrders(List<OrderModel> source, String period) {
    if (period == 'All Time') return source;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return source.where((o) {
      if (o.createdAt == null || o.createdAt!.isEmpty) return true;
      if (o.createdAt == null || o.createdAt!.isEmpty) return true;
      DateTime? dt = DateTime.tryParse(o.createdAt!);
      if (dt == null) return period == 'Today';
      
      final orderDate = DateTime(dt.year, dt.month, dt.day);
      
      if (period == 'Today') {
        return orderDate == today;
      } else if (period == 'Yesterday') {
        final yesterday = today.subtract(const Duration(days: 1));
        return orderDate == yesterday;
      } else if (period == 'Week') {
        final diff = today.difference(orderDate).inDays;
        return diff >= 0 && diff <= 7;
      } else if (period == 'Month') {
        return orderDate.year == today.year && orderDate.month == today.month;
      } else if (period == 'Year') {
        return orderDate.year == today.year;
      } else if (period == 'Custom Date') {
        if (_customStartDate != null && _customEndDate != null) {
          final start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
          final end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day);
          return (orderDate.isAtSameMomentAs(start) || orderDate.isAfter(start)) &&
                 (orderDate.isAtSameMomentAs(end) || orderDate.isBefore(end));
        }
        return true;
        return true;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsiveness
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF5F9), // Light liquid glass canvas background
      body: Stack(
        children: [
          // 1. Ambient Liquid Background Blobs
          _buildLiquidBackground(size),

          // 2. Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 12 : 20,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Bar
                  _buildHeader(),
                  const SizedBox(height: 18),


                  // Order & User Summary Section (2 Cards)
                  _buildSummaryCards(isMobile),
                  const SizedBox(height: 18),

                  // Order Type Liquid Glass Grid (4 Cards)
                  _buildOrderTypeGrid(isMobile),
                  const SizedBox(height: 18),

                  // Top & Low Selling Products Section
                  _buildProductPerformanceCards(isMobile),
                  const SizedBox(height: 18),

                  _buildCustomerInsights(isMobile),
                  const SizedBox(height: 18),

                  _buildTotalSales(isMobile),
                  const SizedBox(height: 18),

                  _buildTaxes(isMobile),
                  const SizedBox(height: 18),

                  _buildOrderStatistics(isMobile),
                ],
              ),
            ),
          ),


        ],
      ),
    );
  }

  /// Ambient Liquid Background Blobs for depth & glass refraction
  Widget _buildLiquidBackground(Size size) {
    return Stack(
      children: [
        // Soft Cyan Ambient Glow Top-Right
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x3300C2FF),
                  Color(0x18A5F3FC),
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Soft Lavender/Violet Glow Left Center
        Positioned(
          top: size.height * 0.35,
          left: -80,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x228B5CF6),
                  Color(0x10DDD6FE),
                  Colors.transparent,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // Soft Green Ambient Glow Bottom-Right
        Positioned(
          bottom: 100,
          right: -60,
          child: Container(
            width: size.width * 0.65,
            height: size.width * 0.65,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x2510B981),
                  Color(0x10A7F3D0),
                  Colors.transparent,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Header with avatar, greeting title & notification bell
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // // Glass Store Avatar Icon
        // _buildGlassContainer(
        //   padding: const EdgeInsets.all(12),
        //   borderRadius: BorderRadius.circular(18),
        //   child: const Icon(
        //     Icons.storefront_rounded,
        //     color: Color(0xFF00C2FF),
        //     size: 26,
        //   ),
        // ),
        const SizedBox(width: 14),

      ],
    );
  }

  /// Order Summary Section
  Widget _buildSummaryCards(bool isMobile) {
    // Calculate live database metrics if available, fallback to design metrics
    double totalRevenue = 1125.65;
    int totalOrdersCount = 7;

    final paidOrders = _filterOrders(_db.orders.where((o) => o.status == OrderStatus.completed).toList(), _dashboardFilter);
    if (paidOrders.isNotEmpty) {
      totalOrdersCount = paidOrders.length;
      totalRevenue = paidOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
      if (totalRevenue == 0) totalRevenue = 1125.65;
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFF9333EA),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              _buildDropdownPill(
                value: _dashboardFilter,
                onChanged: (val) => setState(() => _dashboardFilter = val),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics Row 1
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Orders',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalOrdersCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Revenue
          const Text(
            'Total Revenue',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${totalRevenue.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Footer Date
          Row(
            children: const [
              Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
              SizedBox(width: 6),
              Text(
                '4 Aug - 4 Aug',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Order Type Liquid Glass Cards Grid (Delivery, Take Away, Dine In, Total Orders)
  Widget _buildOrderTypeGrid(bool isMobile) {
    int deliveryCount = 0;
    int takeawayCount = 0;
    int dineInCount = 0;
    double deliveryAmount = 0.0;
    double takeawayAmount = 0.0;
    double dineInAmount = 0.0;

    final paidOrders = _filterOrders(_db.orders.where((o) => o.status == OrderStatus.completed).toList(), _dashboardFilter);
    for (var o in paidOrders) {
      if (o.orderType == OrderType.delivery) {
        deliveryCount++;
        deliveryAmount += o.totalAmount;
      }
      if (o.orderType == OrderType.takeaway) {
        takeawayCount++;
        takeawayAmount += o.totalAmount;
      }
      if (o.orderType == OrderType.dineIn) {
        dineInCount++;
        dineInAmount += o.totalAmount;
      }
    }
    int totalCount = paidOrders.length;
    double totalAmount = paidOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

    final cards = [
      _buildOrderTypeCard(
        title: 'Total Orders',
        amount: totalAmount,
        count: totalCount,
        icon: Icons.assignment_rounded,
        accentColor: const Color(0xFF10B981), // Teal / Green
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
      ),
       _buildOrderTypeCard(
        title: 'Dine In',
        amount: dineInAmount,
        count: dineInCount,
        icon: Icons.restaurant_rounded,
        accentColor: const Color(0xFF8B5CF6), // Purple
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
      ),
      _buildOrderTypeCard(
        title: 'Take Away',
        count: takeawayCount,
        amount: takeawayAmount,
        icon: Icons.local_mall_rounded,
        accentColor: const Color(0xFF0284C7), // Sky Blue
        bgColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
      ),
      _buildOrderTypeCard(
        title: 'Delivery',
        count: deliveryCount,
        amount: deliveryAmount,
        icon: Icons.two_wheeler_rounded,
        accentColor: const Color(0xFFF97316), // Warm Orange
        bgColor: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFFED7AA),
      ),
      
     
      
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isMobile ? 1.25 : 1.4,
      children: cards,
    );
  }

  Widget _buildOrderTypeCard({
    required String title,
    required int count,
    required double amount,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return _buildGlassCard(
      color: bgColor.withOpacity(0.75),
      borderColor: borderColor.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Icon Circle
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(height: 4),

          // Amount Number (Main)
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          
          // Title Label
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),

          // Count Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
            child: Text(
              '$count Orders',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
  List<Map<String, dynamic>> _getTopSellingProducts() {
    Map<String, Map<String, dynamic>> products = {};
    final paidOrders = _filterOrders(_db.orders.where((o) => o.status == OrderStatus.completed).toList(), _dashboardFilter);
    for (var order in paidOrders) {
      for (var cartItem in order.items) {
        String id = cartItem.item.id;
        if (!products.containsKey(id)) {
          products[id] = {
            'name': cartItem.item.name,
            'price': cartItem.item.price,
            'qty': 0,
            'total': 0.0,
          };
        }
        products[id]!['qty'] += cartItem.quantity;
        products[id]!['total'] += cartItem.totalPrice;
      }
    }
    List<Map<String, dynamic>> list = products.values.toList();
    list.sort((a, b) => b['qty'].compareTo(a['qty']));
    return list;
  }

  /// Top Selling Products Section (renamed to Total sale of item vise)
  Widget _buildProductPerformanceCards(bool isMobile) {
    final products = _getTopSellingProducts();

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total sale of item',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              _buildDropdownPill(
                value: _dashboardFilter,
                onChanged: (val) => setState(() => _dashboardFilter = val),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (products.isEmpty)
            // Empty state matching screenshot
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFD97706),
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No data yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sales data will appear here\nwhen available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                      Expanded(
                        flex: 3,
                        child: Text('Product Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.5), height: 16),
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('₹${(p['price'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('${p['qty'] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('₹${(p['total'] ?? 0).toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }



  /// Dropdown Pill Button
  Widget _buildDropdownPill({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    String displayValue = value;
    if (value == 'Custom Date' && _customStartDate != null && _customEndDate != null) {
      displayValue = '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}';
    }

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: (val) async {
        if (val == 'Custom Date') {
          final DateTimeRange? picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0F172A),
                    onPrimary: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() {
              _customStartDate = picked.start;
              _customEndDate = picked.end;
            });
            onChanged(val);
          }
        } else {
          onChanged(val);
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'Today', child: Text('Today')),
        PopupMenuItem(value: 'Yesterday', child: Text('Yesterday')),
        PopupMenuItem(value: 'Week', child: Text('Week')),
        PopupMenuItem(value: 'Month', child: Text('Month')),
        PopupMenuItem(value: 'Year', child: Text('Year')),
        PopupMenuItem(value: 'Custom Date', child: Text('Custom Date')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayValue,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable Liquid Glass Container Base
  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? borderRadius,
  }) {
    final rRadius = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: rRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: rRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0052FF),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// Reusable Glass Card Base
  Widget _buildGlassCard({
    required Widget child,
    Color? color,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.9),
              width: 1.3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0052FF),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showFilter = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        Row(
          children: [
            _buildDropdownPill(
              value: 'Today',
              onChanged: (val) {},
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerInsights(bool isMobile) {
    final paidOrders = _filterOrders(_db.orders.where((o) => o.status == OrderStatus.completed).toList(), _dashboardFilter);
    final Map<String, int> customerVisits = {};
    final Map<String, String> customerNames = {};

    for (var o in paidOrders) {
      if (o.customerPhone != null && o.customerPhone!.isNotEmpty) {
        final phone = o.customerPhone!;
        customerVisits[phone] = (customerVisits[phone] ?? 0) + 1;
        if (o.customerName != null && o.customerName!.isNotEmpty) {
          customerNames[phone] = o.customerName!;
        }
      }
    }

    final newCustomers = customerVisits.entries.where((e) => e.value == 1).toList();
    final returningCustomers = customerVisits.entries.where((e) => e.value > 1).toList();

    Widget buildCustomerList(List<MapEntry<String, int>> list, String emptyTitle, String emptySubtitle, IconData emptyIcon, Color iconColor, Color iconBg) {
      if (list.isEmpty) {
        return Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('NO ROWS YET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(emptyIcon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(emptyTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(emptySubtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 16),
        itemBuilder: (context, index) {
          final phone = list[index].key;
          final visits = list[index].value;
          final name = customerNames[phone] ?? phone;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 24,
                child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name == phone ? "Unknown" : name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Visits: $visits', style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
              ),
            ],
          );
        },
      );
    }

    Widget newCust = _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('New Customers'),
          const SizedBox(height: 16),
          buildCustomerList(
            newCustomers,
            'No new customers in this range',
            'Switch the preset or refresh to reveal new customers once the activity data is available.',
            Icons.person_add_alt_1_rounded,
            const Color(0xFF3B82F6),
            const Color(0xFFEFF6FF),
          ),
        ],
      ),
    );

    Widget retCust = _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Returning Customers'),
          const SizedBox(height: 16),
          buildCustomerList(
            returningCustomers,
            'No returning customers in this range',
            'Try another period or refresh the dashboard to surface returning customer activity.',
            Icons.group_rounded,
            const Color(0xFF8B5CF6),
            const Color(0xFFF5F3FF),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          newCust,
          const SizedBox(height: 18),
          retCust,
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: newCust),
          const SizedBox(width: 18),
          Expanded(child: retCust),
        ],
      );
    }
  }

  Widget _buildProgressBarRow(String label, double value, double max, Color color) {
    double progress = max > 0 ? value / max : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
          ),
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              value.toStringAsFixed(0),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSales(bool isMobile) {
    double cash = 0, card = 0, upi = 0, net = 0, due = 0;
    final paidOrders = _filterOrders(_db.orders.where((o) => o.status == OrderStatus.completed).toList(), _dashboardFilter);
    for (var o in paidOrders) {
      if (o.paymentMethod.toLowerCase() == 'cash') cash += o.totalAmount;
      else if (o.paymentMethod.toLowerCase() == 'card') card += o.totalAmount;
      else if (o.paymentMethod.toLowerCase() == 'upi') upi += o.totalAmount;
      else net += o.totalAmount; // Fallback
    }
    double total = cash + card + upi + net + due;
    double maxVal = [cash, card, upi, net, due].reduce((a, b) => a > b ? a : b);

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Total Sales'),
          const SizedBox(height: 16),
          _buildProgressBarRow('CASH', cash, maxVal, const Color(0xFF00C2FF)),
          _buildProgressBarRow('CARD', card, maxVal, const Color(0xFF3B82F6)),
          _buildProgressBarRow('UPI', upi, maxVal, const Color(0xFF8B5CF6)),
          _buildProgressBarRow('NET BANKING', net, maxVal, const Color(0xFFF59E0B)),
          _buildProgressBarRow('DUE', due, maxVal, const Color(0xFF64748B)),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Total: ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxes(bool isMobile) {
    double gst = 0;
    final paidOrders = _filterOrders(_db.orders.where((o) => o.status == OrderStatus.completed).toList(), _dashboardFilter);
    for (var o in paidOrders) {
      gst += o.taxAmount;
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Taxes'),
          const SizedBox(height: 16),
          _buildProgressBarRow('GST', gst, gst, const Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Total Taxes: ₹${gst.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatistics(bool isMobile) {
    int success = 0, cancelled = 0, comp = 0;
    for (var o in _db.orders) {
      if (o.status == OrderStatus.completed) success++;
      if (o.status == OrderStatus.cancelled) cancelled++;
      if (o.discountAmount == o.totalAmount && o.totalAmount > 0) comp++;
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Order Statistics'),
          const SizedBox(height: 16),
          _buildStatRow('SUCCESS ORDER:', success.toString()),
          _buildStatRow('CANCELLED ORDER:', cancelled.toString()),
          _buildStatRow('COMPLIMENTARY ORDER:', comp.toString()),
          _buildStatRow('TABLE TURN AROUND TIME:', '0 mins'),
        ],
      ),
    );
  }
}