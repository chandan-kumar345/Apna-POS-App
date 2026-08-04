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
  String _orderSummaryFilter = 'Today';
  String _userSummaryFilter = 'Today';
  String _trendFilter = 'This Week';
  String _topSellingFilter = 'Today';
  String _lowSellingFilter = 'Today';

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
                isMobile ? 100 : 110, // Padding for floating nav bar
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Bar
                  _buildHeader(),
                  const SizedBox(height: 18),

                  // Hero Glass Banner Card
                  _buildHeroBanner(isMobile),
                  const SizedBox(height: 18),

                  // Order & User Summary Section (2 Cards)
                  _buildSummaryCards(isMobile),
                  const SizedBox(height: 18),

                  // Order Type Liquid Glass Grid (4 Cards)
                  _buildOrderTypeGrid(isMobile),
                  const SizedBox(height: 18),

                  // Customer Trends Dual Bar Chart
                  _buildCustomerTrendsCard(),
                  const SizedBox(height: 18),

                  // Top & Low Selling Products Section
                  _buildProductPerformanceCards(isMobile),
                ],
              ),
            ),
          ),

          // 3. Floating Liquid Glass Bottom Navigation Bar
          Positioned(
            left: isMobile ? 16 : (size.width - 450) / 2,
            right: isMobile ? 16 : (size.width - 450) / 2,
            bottom: 16,
            child: _buildFloatingNavBar(),
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
      children: [
        // Glass Store Avatar Icon
        _buildGlassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(18),
          child: const Icon(
            Icons.storefront_rounded,
            color: Color(0xFF00C2FF),
            size: 26,
          ),
        ),
        const SizedBox(width: 14),

        // Greeting Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'POS CONTROL CENTER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: const [
                  Flexible(
                    child: Text(
                      'Hello, Admin!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text('👋', style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 1),
              const Text(
                "Here's what's happening today.",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // Glass Notification Bell Button with Notification Indicator Dot
        _buildGlassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(50),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF334155),
                size: 22,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Liquid Glass Hero Banner Widget
  Widget _buildHeroBanner(bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 20 : 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8CE3D2), // Soft pastel cyan/teal
                Color(0xFFA8E0FF), // Ocean light blue
                Color(0xFFB8D5FF), // Soft glass violet blue
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.7),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180052FF),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Shiny Glass Reflection Overlays
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),

              // Content Layout
              Row(
                children: [
                  // Text Content Left
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Run your outlets from\none smart dashboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Color(0x22000000),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Track orders, revenue, customer movement & store performance in real-time.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.white.withOpacity(0.92),
                          ),
                        ),
                        const SizedBox(height: 18),
                        
                        // Glass Pill Button
                        InkWell(
                          onTap: () {
                            if (widget.onNavigateTab != null) {
                              widget.onNavigateTab!(6); // Reports & Insights
                            }
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.2,
                              ),
                            ),
                            child: const Text(
                              'View Insights',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3D Glass Graphic Illustration Right
                  if (!isMobile) const SizedBox(width: 16),
                  Expanded(
                    flex: isMobile ? 4 : 4,
                    child: _build3DGlassChartGraphic(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3D Glass Graphic Illustration component matching screenshot
  Widget _build3DGlassChartGraphic() {
    return AspectRatio(
      aspectRatio: 1.1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Frosted Glass Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0052FF).withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Line Chart Trace Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C2FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Simulated 3D Glass Bars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _build3DBar(35, const Color(0xFF38BDF8)),
                      _build3DBar(55, const Color(0xFF10B981)),
                      _build3DBar(42, const Color(0xFF38BDF8)),
                      _build3DBar(75, const Color(0xFF059669)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating Overlay Pie Chart Glass Card
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF10B981),
                        Color(0xFF00C2FF),
                        Color(0xFF6366F1),
                        Color(0xFF10B981),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
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

  Widget _build3DBar(double height, Color color) {
    return Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  /// Order & User Summary Section (2 Cards)
  Widget _buildSummaryCards(bool isMobile) {
    // Calculate live database metrics if available, fallback to design metrics
    double totalRevenue = 1125.65;
    int totalOrdersCount = 7;
    int storeVisits = 18;

    if (_db.orders.isNotEmpty) {
      totalOrdersCount = _db.orders.length;
      totalRevenue = _db.orders.fold(0.0, (sum, o) => sum + o.totalAmount);
      if (totalRevenue == 0) totalRevenue = 1125.65;
    }

    final orderSummaryWidget = _buildGlassCard(
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
                value: _orderSummaryFilter,
                onChanged: (val) => setState(() => _orderSummaryFilter = val),
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
                  children: const [
                    Text(
                      'Total Sales',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'vs. Orders',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalOrdersCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '0.00%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
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

    final userSummaryWidget = _buildGlassCard(
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
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0284C7),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'User Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              _buildDropdownPill(
                value: _userSummaryFilter,
                onChanged: (val) => setState(() => _userSummaryFilter = val),
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
                  children: const [
                    Text(
                      'Total Store Visits',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'vs. Visits',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$storeVisits',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '0.00%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Conversions Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Total Conversions',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '0%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'vs. Converted',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '105.56%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

    if (isMobile) {
      return Column(
        children: [
          orderSummaryWidget,
          const SizedBox(height: 14),
          userSummaryWidget,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: orderSummaryWidget),
        const SizedBox(width: 14),
        Expanded(child: userSummaryWidget),
      ],
    );
  }

  /// Order Type Liquid Glass Cards Grid (Delivery, Take Away, Dine In, Total Orders)
  Widget _buildOrderTypeGrid(bool isMobile) {
    int deliveryCount = 0;
    int takeawayCount = 0;
    int dineInCount = 0;

    for (var o in _db.orders) {
      if (o.orderType == OrderType.delivery) deliveryCount++;
      if (o.orderType == OrderType.takeaway) takeawayCount++;
      if (o.orderType == OrderType.dineIn) dineInCount++;
    }
    int totalCount = _db.orders.length;

    final cards = [
      _buildOrderTypeCard(
        title: 'Delivery',
        count: deliveryCount,
        icon: Icons.two_wheeler_rounded,
        accentColor: const Color(0xFFF97316), // Warm Orange
        bgColor: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFFED7AA),
      ),
      _buildOrderTypeCard(
        title: 'Take Away',
        count: takeawayCount,
        icon: Icons.local_mall_rounded,
        accentColor: const Color(0xFF0284C7), // Sky Blue
        bgColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
      ),
      _buildOrderTypeCard(
        title: 'Dine In',
        count: dineInCount,
        icon: Icons.restaurant_rounded,
        accentColor: const Color(0xFF8B5CF6), // Purple
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
      ),
      _buildOrderTypeCard(
        title: 'Total Orders',
        count: totalCount,
        icon: Icons.assignment_rounded,
        accentColor: const Color(0xFF10B981), // Teal / Green
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
      ),
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isMobile ? 1.15 : 1.25,
      children: cards,
    );
  }

  Widget _buildOrderTypeCard({
    required String title,
    required int count,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return _buildGlassCard(
      color: bgColor.withOpacity(0.75),
      borderColor: borderColor.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Icon Circle
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 8),

          // Count Number
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),

          // Title Label
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),

          // Orders Count Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
            child: Text(
              'Orders $count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Customer Trends Dual Bar Chart Card
  Widget _buildCustomerTrendsCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Trends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              _buildDropdownPill(
                value: _trendFilter,
                onChanged: (val) => setState(() => _trendFilter = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart Visualization
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-Axis Labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('20', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text('15', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text('10', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text('5', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text('0', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(width: 8),

                // Chart Bars Area
                Expanded(
                  child: Stack(
                    children: [
                      // Horizontal Grid Lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          5,
                          (_) => Divider(
                            color: const Color(0xFFE2E8F0).withOpacity(0.7),
                            height: 1,
                            thickness: 1,
                          ),
                        ),
                      ),

                      // Bars Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildDualBarGroup('28/07', 9, 2),
                          _buildDualBarGroup('30/07', 13, 1),
                          _buildDualBarGroup('31/07', 15, 6),
                          _buildDualBarGroup('01/08', 19, 8),
                          _buildDualBarGroup('02/08', 13, 10),
                          _buildDualBarGroup('03/08', 3, 1),
                          _buildDualBarGroup('04/08', 1, 0),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend Footer
          Row(
            children: [
              _buildLegendItem('New Customers', const Color(0xFF10B981)),
              const SizedBox(width: 20),
              _buildLegendItem('Returning Customers', const Color(0xFF38BDF8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDualBarGroup(String label, int newCount, int returningCount) {
    // Max height scale is 20
    const maxHeight = 130.0;
    final h1 = (newCount / 20.0) * maxHeight;
    final h2 = (returningCount / 20.0) * maxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // New Customers Bar (Green)
            Container(
              width: 12,
              height: h1 < 3 ? 3 : h1,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 3),

            // Returning Customers Bar (Cyan/Blue)
            Container(
              width: 12,
              height: h2 < 2 ? 2 : h2,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  /// Top & Low Selling Products Section
  Widget _buildProductPerformanceCards(bool isMobile) {
    final topSellingCard = _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Selling Products',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              _buildDropdownPill(
                value: _topSellingFilter,
                onChanged: (val) => setState(() => _topSellingFilter = val),
              ),
            ],
          ),
          const SizedBox(height: 24),

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
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    final lowSellingCard = _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Low Selling Products',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              _buildDropdownPill(
                value: _lowSellingFilter,
                onChanged: (val) => setState(() => _lowSellingFilter = val),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Empty state matching screenshot
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3E8FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.trending_down_rounded,
                    color: Color(0xFF9333EA),
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
                  'Try adjusting the date range or\ncheck back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          topSellingCard,
          const SizedBox(height: 14),
          lowSellingCard,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: topSellingCard),
        const SizedBox(width: 14),
        Expanded(child: lowSellingCard),
      ],
    );
  }

  /// Floating Liquid Glass Bottom Navigation Bar
  Widget _buildFloatingNavBar() {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0052FF),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Dashboard Tab (Active)
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Dashboard',
                isActive: _activeNavIndex == 0,
              ),

              // 2. Orders Tab
              _buildNavItem(
                index: 1,
                icon: Icons.shopping_bag_outlined,
                label: 'Orders',
                isActive: _activeNavIndex == 1,
              ),

              // 3. Center Floating Liquid Gradient Action Button
              GestureDetector(
                onTap: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(1); // Open POS Billing
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF00C2FF),
                        Color(0xFF0052FF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0052FF).withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),

              // 4. Reports Tab
              _buildNavItem(
                index: 3,
                icon: Icons.pie_chart_outline_rounded,
                label: 'Reports',
                isActive: _activeNavIndex == 3,
              ),

              // 5. More Tab
              _buildNavItem(
                index: 4,
                icon: Icons.grid_view_rounded,
                label: 'More',
                isActive: _activeNavIndex == 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    const activeColor = Color(0xFF10B981);
    const inactiveColor = Color(0xFF94A3B8);

    return InkWell(
      onTap: () {
        setState(() => _activeNavIndex = index);
        if (widget.onNavigateTab != null) {
          switch (index) {
            case 0:
              widget.onNavigateTab!(0); // Dashboard
              break;
            case 1:
              widget.onNavigateTab!(3); // Orders
              break;
            case 3:
              widget.onNavigateTab!(6); // Reports
              break;
            case 4:
              widget.onNavigateTab!(9); // Settings/More
              break;
          }
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dropdown Pill Button
  Widget _buildDropdownPill({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
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
            value,
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
}
