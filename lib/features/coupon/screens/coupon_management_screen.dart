import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/coupon_service.dart';
import 'coupon_form_screen.dart';
import 'coupon_redemption_report_screen.dart';

class CouponManagementScreen extends StatefulWidget {
  const CouponManagementScreen({super.key});

  @override
  State<CouponManagementScreen> createState() => _CouponManagementScreenState();
}

class _CouponManagementScreenState extends State<CouponManagementScreen> {
  final _couponService = CouponService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<CouponModel> _coupons = [];
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'inactive', 'expired'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    try {
      final res = await _couponService.getCoupons(
        search: _searchQuery,
        status: _selectedStatusFilter != 'all' && _selectedStatusFilter != 'expired'
            ? _selectedStatusFilter
            : null,
      );
      if (mounted) {
        setState(() {
          _coupons = res.coupons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load coupons: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  List<CouponModel> get _filteredCoupons {
    return _coupons.where((c) {
      if (_selectedStatusFilter == 'active') {
        return c.isActive && !c.isExpired;
      } else if (_selectedStatusFilter == 'inactive') {
        return !c.isActive;
      } else if (_selectedStatusFilter == 'expired') {
        return c.isExpired;
      }
      return true;
    }).toList();
  }

  int get _totalActive => _coupons.where((c) => c.isActive && !c.isExpired).length;
  int get _totalRedemptions => _coupons.fold(0, (sum, c) => sum + c.totalTimesUsed);

  void _openCreateCouponScreen([CouponModel? coupon]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CouponFormScreen(
          existingCoupon: coupon,
          onSaved: _loadCoupons,
        ),
      ),
    );
  }

  Future<void> _toggleStatus(CouponModel coupon) async {
    try {
      await _couponService.toggleCoupon(coupon.id);
      _loadCoupons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling coupon: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _confirmDelete(CouponModel coupon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Coupon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete coupon "${coupon.code}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _couponService.deleteCoupon(coupon.id);
        _loadCoupons();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Coupon deleted successfully'), backgroundColor: Color(0xFF051C48)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting coupon: $e'), backgroundColor: Colors.red.shade700),
          );
        }
      }
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 5,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, color: color, size: 13.5),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(CouponModel coupon) {
    final isExpired = coupon.isExpired;
    final statusColor = !coupon.isActive
        ? const Color(0xFF64748B)
        : isExpired
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669);
    final statusBgColor = !coupon.isActive
        ? const Color(0xFFF1F5F9)
        : isExpired
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFECFDF5);
    final statusBorderColor = !coupon.isActive
        ? const Color(0xFFCBD5E1)
        : isExpired
            ? const Color(0xFFFECACA)
            : const Color(0xFFA7F3D0);
    final statusText = !coupon.isActive
        ? 'Disabled'
        : isExpired
            ? 'Expired'
            : 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: coupon.isActive && !isExpired ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code Badge, Status Badge wrapped, Switch on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Code Badge
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: coupon.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied ${coupon.code}'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF021B54).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF021B54).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.confirmation_number_rounded, size: 11, color: Color(0xFF021B54)),
                              const SizedBox(width: 3.5),
                              Text(
                                coupon.code,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF021B54),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 3.5),
                              const Icon(Icons.copy_rounded, size: 9, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: statusBorderColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // Switch Toggle
                SizedBox(
                  height: 22,
                  child: Transform.scale(
                    scale: 0.65,
                    child: Switch(
                      value: coupon.isActive,
                      activeThumbColor: const Color(0xFF021B54),
                      onChanged: (val) => _toggleStatus(coupon),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Middle Row: Discount Value & Title with visible text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.formattedDiscount,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (coupon.title.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          coupon.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                      if (coupon.description.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          coupon.description,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Usage Counter Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Usage', style: TextStyle(fontSize: 7.5, color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(
                        '${coupon.totalTimesUsed} / ${coupon.totalUsageLimit > 0 ? coupon.totalUsageLimit : "∞"}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Metadata Chips: Product Applicability, Min Cart, Dates, Order Types (Wrapped)
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                if (coupon.applicableProducts.isNotEmpty)
                  _buildMetaChip(
                    Icons.restaurant_menu_rounded,
                    '${coupon.applicableProducts.length} Product(s)',
                    textColor: const Color(0xFF0052FF),
                    iconColor: const Color(0xFF0052FF),
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                  )
                else
                  _buildMetaChip(
                    Icons.all_inbox_rounded,
                    'All Products',
                    textColor: const Color(0xFF475569),
                    iconColor: const Color(0xFF475569),
                    bgColor: const Color(0xFFF8FAFD),
                    borderColor: const Color(0xFFE2E8F0),
                  ),
                if (coupon.minCartAmount > 0)
                  _buildMetaChip(Icons.shopping_bag_outlined, 'Min Cart: ₹${coupon.minCartAmount.toStringAsFixed(0)}'),
                if (coupon.endDate != null)
                  _buildMetaChip(Icons.event_rounded, 'Till ${DateFormat('dd MMM yyyy').format(coupon.endDate!)}')
                else
                  _buildMetaChip(Icons.all_inclusive_rounded, 'No Expiry'),
                _buildMetaChip(
                  Icons.delivery_dining_rounded,
                  coupon.orderTypes.map((t) => t == 'dineIn' ? 'Dine-In' : t == 'takeaway' ? 'Takeaway' : 'Delivery').join(', '),
                ),
              ],
            ),
            const SizedBox(height: 6),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 3),

            // Bottom Actions: Redemptions Log, Edit, Delete
            Row(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => CouponRedemptionReportScreen(coupon: coupon),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 12, color: Color(0xFF0052FF)),
                        SizedBox(width: 3.5),
                        Text(
                          'Redemptions',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0052FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit Coupon',
                  onPressed: () => _openCreateCouponScreen(coupon),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete Coupon',
                  onPressed: () => _confirmDelete(coupon),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    IconData icon,
    String text, {
    Color? textColor,
    Color? iconColor,
    Color? bgColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9.5, color: iconColor ?? textColor ?? const Color(0xFF475569)),
          const SizedBox(width: 3.5),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: textColor ?? const Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            // Circular glass back button (matches other app screens)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Coupons & Offers',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'Discounts, promo codes & deals',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            // Circular glass refresh button
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                tooltip: 'Refresh Coupons',
                onPressed: _loadCoupons,
              ),
            ),
            const SizedBox(width: 8),
            // PLUS ICON ONLY TO CREATE COUPON (matches prompt requirement)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0052FF), Color(0xFF0038E0)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0052FF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                tooltip: 'Create Coupon',
                onPressed: () => _openCreateCouponScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCoupons;

    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Column(
        children: [
          // Top Header Bar (Matching Apna POS Signature Theme)
          _buildTopHeader(),

          // Curved Neumorphic Sheet Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F4F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x30001C55),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: RefreshIndicator(
                  onRefresh: _loadCoupons,
                  color: const Color(0xFF0052FF),
                  child: Column(
                    children: [
                      // Top Summary Cards (Responsive & Wrapped)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              title: 'Total Coupons',
                              value: '${_coupons.length}',
                              icon: Icons.confirmation_number_outlined,
                              color: const Color(0xFF0052FF),
                            ),
                            const SizedBox(width: 7),
                            _buildSummaryCard(
                              title: 'Active Offers',
                              value: '$_totalActive',
                              icon: Icons.check_circle_outline_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 7),
                            _buildSummaryCard(
                              title: 'Redemptions',
                              value: '$_totalRedemptions',
                              icon: Icons.redeem_rounded,
                              color: const Color(0xFFD97706),
                            ),
                          ],
                        ),
                      ),

                      // Search Bar & Filter Chips (Neumorphic & Wrapped)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1.5)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 34,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) {
                                    setState(() => _searchQuery = val.trim());
                                  },
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: 'Search by coupon code or title...',
                                    hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF475569)),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 13),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFD),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0052FF))),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: [
                                  {'key': 'all', 'label': 'All', 'count': _coupons.length},
                                  {'key': 'active', 'label': 'Active', 'count': _totalActive},
                                  {'key': 'inactive', 'label': 'Inactive', 'count': _coupons.where((c) => !c.isActive).length},
                                  {'key': 'expired', 'label': 'Expired', 'count': _coupons.where((c) => c.isExpired).length},
                                ].map((tab) {
                                  final key = tab['key'] as String;
                                  final label = tab['label'] as String;
                                  final count = tab['count'] as int;
                                  final isSelected = _selectedStatusFilter == key;

                                  return InkWell(
                                    onTap: () => setState(() => _selectedStatusFilter = key),
                                    borderRadius: BorderRadius.circular(7),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF021B54) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF021B54) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected ? Colors.white : const Color(0xFF334155),
                                            ),
                                          ),
                                          const SizedBox(width: 3.5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: isSelected ? Colors.white : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Coupon List or Redesigned Empty State
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052FF)))
                            : filtered.isEmpty
                                ? Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Glowing Circular Icon Badge
                                          Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x180052FF),
                                                  blurRadius: 18,
                                                  spreadRadius: 2,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.confirmation_number_outlined,
                                                size: 32,
                                                color: Color(0xFF0052FF),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          const Text(
                                            'No coupons yet',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 260),
                                            child: const Text(
                                              'Create your first offer to boost sales, retain customers, and reward loyalty.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF64748B),
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF0052FF), Color(0xFF0038E0)],
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF0052FF).withValues(alpha: 0.35),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _openCreateCouponScreen(),
                                                borderRadius: BorderRadius.circular(10),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Create First Coupon',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) => _buildCouponCard(filtered[index]),
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
