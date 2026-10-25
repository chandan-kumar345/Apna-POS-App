import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/coupon_service.dart';
import '../../storefront/models/storefront_model.dart';
import '../../storefront/screens/customer_storefront_screen.dart';
import '../dialogs/promotional_banner_dialog.dart';
import 'coupon_form_screen.dart';
import 'coupon_redemption_report_screen.dart';

class CouponManagementScreen extends StatefulWidget {
  const CouponManagementScreen({super.key});

  @override
  State<CouponManagementScreen> createState() => _CouponManagementScreenState();
}

class _CouponManagementScreenState extends State<CouponManagementScreen> {
  final _couponService = CouponService();
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  final _bannerSearchController = TextEditingController();

  int _selectedMainTab = 0; // 0: Coupons & Codes, 1: Promotional Banners
  bool _isLoading = true;
  List<CouponModel> _coupons = [];
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'inactive', 'expired'
  String _searchQuery = '';

  String _bannerFilter = 'all'; // 'all', 'active', 'draft', 'linked'
  String _bannerSearch = '';

  @override
  void initState() {
    super.initState();
    // Instant 0ms cached load from memory
    _coupons = List.from(_couponService.cachedCoupons);
    _isLoading = _coupons.isEmpty;
    _loadCoupons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    // Only show full loading spinner if we don't have any cached coupons
    if (_coupons.isEmpty) {
      setState(() => _isLoading = true);
    }
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
        if (_coupons.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load coupons: $e'), backgroundColor: Colors.red.shade700),
          );
        }
      }
    }
  }

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  List<CouponModel> get _filteredCoupons {
    final query = _searchQuery.toLowerCase();
    return _coupons.where((c) {
      if (_selectedStatusFilter == 'active') {
        if (!c.isActive || c.isExpired) return false;
      } else if (_selectedStatusFilter == 'inactive') {
        if (c.isActive) return false;
      } else if (_selectedStatusFilter == 'expired') {
        if (!c.isExpired) return false;
      }
      if (query.isNotEmpty) {
        final inCode = c.code.toLowerCase().contains(query);
        final inTitle = c.title.toLowerCase().contains(query);
        final inDesc = c.description.toLowerCase().contains(query);
        if (!inCode && !inTitle && !inDesc) return false;
      }
      return true;
    }).toList();
  }

  int get _totalActive => _coupons.where((c) => c.isActive && !c.isExpired).length;
  int get _totalRedemptions => _coupons.fold(0, (sum, c) => sum + c.totalTimesUsed);

  List<StorefrontBanner> get _filteredBanners {
    final all = _db.storefrontBanners;
    return all.where((b) {
      if (_bannerFilter == 'active' && !b.isActive) return false;
      if (_bannerFilter == 'draft' && b.isActive) return false;
      if (_bannerFilter == 'linked' && (b.couponCode == null || b.couponCode!.isEmpty)) return false;
      if (_bannerSearch.isNotEmpty) {
        final q = _bannerSearch.toLowerCase();
        final inTag = b.tag.toLowerCase().contains(q);
        final inHeadline = b.headline.toLowerCase().contains(q);
        final inSubtitle = b.subtitle.toLowerCase().contains(q);
        final inCoupon = (b.couponCode ?? '').toLowerCase().contains(q);
        if (!inTag && !inHeadline && !inSubtitle && !inCoupon) return false;
      }
      return true;
    }).toList();
  }

  int get _totalActiveBanners => _db.storefrontBanners.where((b) => b.isActive).length;
  int get _totalLinkedBanners => _db.storefrontBanners.where((b) => b.couponCode != null && b.couponCode!.isNotEmpty).length;

  void _openCreateBannerDialog([StorefrontBanner? banner]) {
    PromotionalBannerDialog.show(
      context: context,
      existingBanner: banner,
      availableCoupons: _coupons.where((c) => c.isActive && !c.isExpired).toList(),
      onSave: (savedBanner) async {
        await _db.saveStorefrontBanner(savedBanner);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Banner "${savedBanner.headline}" saved and live!'),
              backgroundColor: const Color(0xFF051C48),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _toggleBannerStatus(StorefrontBanner banner) async {
    await _db.toggleStorefrontBanner(banner.id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(banner.isActive ? 'Banner moved to Draft' : 'Banner Published to Storefront'),
          backgroundColor: const Color(0xFF051C48),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteBanner(StorefrontBanner banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text('Are you sure you want to delete banner "${banner.headline}"?'),
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
      await _db.deleteStorefrontBanner(banner.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner deleted successfully'), backgroundColor: Color(0xFF051C48)),
        );
      }
    }
  }

  void _openStorefrontPreview() {
    final slug = _db.restaurant?.storefrontSlug.isNotEmpty == true
        ? _db.restaurant!.storefrontSlug
        : 'pizza-47';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerStorefrontScreen(slug: slug, isPreviewMode: true),
      ),
    );
  }

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
    final oldStatus = coupon.isActive;
    // Fast optimistic update for immediate feedback without lag
    setState(() {
      final idx = _coupons.indexWhere((c) => c.id == coupon.id);
      if (idx != -1) {
        _coupons[idx] = _coupons[idx].copyWith(isActive: !oldStatus);
      }
    });

    try {
      await _couponService.toggleCoupon(coupon.id);
    } catch (e) {
      if (mounted) {
        // Revert on error
        setState(() {
          final idx = _coupons.indexWhere((c) => c.id == coupon.id);
          if (idx != -1) {
            _coupons[idx] = _coupons[idx].copyWith(isActive: oldStatus);
          }
        });
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
      final oldList = List<CouponModel>.from(_coupons);
      // Fast optimistic removal
      setState(() {
        _coupons.removeWhere((c) => c.id == coupon.id);
      });

      try {
        await _couponService.deleteCoupon(coupon.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Coupon deleted successfully'), backgroundColor: Color(0xFF051C48)),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _coupons = oldList);
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

                // Switch Toggle (Lightweight & Smooth)
                SizedBox(
                  height: 22,
                  child: Transform.scale(
                    scale: 0.65,
                    child: CupertinoSwitch(
                      value: coupon.isActive,
                      activeTrackColor: const Color(0xFF021B54),
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
                  _buildMetaChip(Icons.event_rounded, 'Till ${_dateFormat.format(coupon.endDate!)}')
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
                  Text(
                    _selectedMainTab == 0 ? 'Coupons & Offers' : 'Promotional Banners',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    _selectedMainTab == 0
                        ? 'Discounts, promo codes & deals'
                        : 'Dynamic customer storefront offers',
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
                tooltip: _selectedMainTab == 0 ? 'Refresh Coupons' : 'Refresh Banners',
                onPressed: () {
                  _loadCoupons();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            // PLUS ICON TO CREATE COUPON OR BANNER
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
                tooltip: _selectedMainTab == 0 ? 'Create Coupon' : 'Create Promotional Banner',
                onPressed: () {
                  if (_selectedMainTab == 0) {
                    _openCreateCouponScreen();
                  } else {
                    _openCreateBannerDialog();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSwitcher() {
    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSwitcherTab(
              index: 0,
              title: 'Coupons & Codes',
              count: _coupons.length,
              icon: Icons.confirmation_number_outlined,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSwitcherTab(
              index: 1,
              title: 'Promotional Banners',
              count: _db.storefrontBanners.length,
              icon: Icons.view_carousel_rounded,
              badgeText: '$_totalActiveBanners Live',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitcherTab({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    String? badgeText,
  }) {
    final isSelected = _selectedMainTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedMainTab = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? const Color(0xFF021B54) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF021B54) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF021B54).withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText ?? '$count',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFF021B54) : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponsSection(List<CouponModel> filtered) {
    return Column(
      children: [
        // Top Summary Cards (Responsive & Wrapped)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
            padding: const EdgeInsets.all(7),
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
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by coupon code or title...',
                      hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF475569)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 12),
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
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
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF021B54) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
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
                                fontSize: 9.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 8,
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
        const SizedBox(height: 6),

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
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x180052FF),
                                    blurRadius: 16,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 30,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No coupons yet',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: const Text(
                                'Create your first offer to boost sales, retain customers, and reward loyalty.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => _openCreateCouponScreen(),
                              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                              label: const Text(
                                'Create First Coupon',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0052FF),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCoupons,
                      color: const Color(0xFF0052FF),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final coupon = filtered[index];
                          return RepaintBoundary(
                            key: ValueKey('coupon_${coupon.id}'),
                            child: _buildCouponCard(coupon),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPromotionalBannersSection() {
    final banners = _filteredBanners;
    final storeSlug = _db.restaurant?.storefrontSlug.isNotEmpty == true
        ? _db.restaurant!.storefrontSlug
        : 'pizza-47';

    return Column(
      children: [
        // 1. Summary Cards (Total Banners, Active on Web, Linked Coupons)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              _buildSummaryCard(
                title: 'Total Banners',
                value: '${_db.storefrontBanners.length}',
                icon: Icons.view_carousel_rounded,
                color: const Color(0xFF0052FF),
              ),
              const SizedBox(width: 7),
              _buildSummaryCard(
                title: 'Live on Web',
                value: '$_totalActiveBanners',
                icon: Icons.visibility_rounded,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 7),
              _buildSummaryCard(
                title: 'With Coupons',
                value: '$_totalLinkedBanners',
                icon: Icons.discount_rounded,
                color: const Color(0xFFD97706),
              ),
            ],
          ),
        ),

        // 2. Dynamic Customer Storefront Banner Tip Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF051C48), Color(0xFF0B2B6D)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 1.5)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Customer Profile Header',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        'apnaposs.vercel.app/$storeSlug',
                        style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _openStorefrontPreview,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_red_eye_rounded, size: 11, color: Color(0xFF021B54)),
                        SizedBox(width: 3),
                        Text(
                          'Preview',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF021B54)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _openCreateBannerDialog(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0052FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'Add',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // 3. Search Bar & Filter Chips (Neumorphic & Wrapped)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.all(7),
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
                  height: 32,
                  child: TextField(
                    controller: _bannerSearchController,
                    onChanged: (val) {
                      setState(() => _bannerSearch = val.trim());
                    },
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search banners by headline, tag or coupon...',
                      hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF475569)),
                      suffixIcon: _bannerSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 12),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _bannerSearchController.clear();
                                setState(() => _bannerSearch = '');
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    {'key': 'all', 'label': 'All Banners', 'count': _db.storefrontBanners.length},
                    {'key': 'active', 'label': 'Live on Web', 'count': _totalActiveBanners},
                    {'key': 'draft', 'label': 'Drafts', 'count': _db.storefrontBanners.where((b) => !b.isActive).length},
                    {'key': 'linked', 'label': 'Has Coupon', 'count': _totalLinkedBanners},
                  ].map((tab) {
                    final key = tab['key'] as String;
                    final label = tab['label'] as String;
                    final count = tab['count'] as int;
                    final isSelected = _bannerFilter == key;

                    return InkWell(
                      onTap: () => setState(() => _bannerFilter = key),
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF021B54) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
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
                                fontSize: 9.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 8,
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
        const SizedBox(height: 6),

        // 4. Banner List or Empty State
        Expanded(
          child: banners.isEmpty
              ? _buildBannersEmptyState()
              : RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: const Color(0xFF0052FF),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    itemCount: banners.length,
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return RepaintBoundary(
                        key: ValueKey('banner_${banner.id}'),
                        child: _buildPromotionalBannerCard(banner),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPromotionalBannerCard(StorefrontBanner banner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: banner.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Banner Preview Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 84,
              width: double.infinity,
              color: Color(banner.accentColorHex),
              child: Stack(
                children: [
                  if (banner.imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                        cacheHeight: 300,
                        errorBuilder: (_, _, _) => Container(color: Color(banner.accentColorHex)),
                      ),
                    ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.78),
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB74D),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                banner.tag,
                                style: const TextStyle(
                                  color: Color(0xFF7C2D12),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (banner.discountText != null && banner.discountText!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  banner.discountText!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          banner.headline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1.5),
                        Text(
                          banner.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        banner.ctaText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Metadata & Controls Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // Live status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: banner.isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: banner.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: banner.isActive ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        banner.isActive ? 'Live on Storefront' : 'Draft (Hidden)',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: banner.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),

                // Linked Coupon Pill if available
                if (banner.couponCode != null && banner.couponCode!.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: banner.couponCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied coupon: ${banner.couponCode}'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_rounded, size: 9, color: Color(0xFF0052FF)),
                          const SizedBox(width: 2.5),
                          Text(
                            banner.couponCode!,
                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF0052FF)),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.copy_rounded, size: 8, color: Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                  ),

                const Spacer(),

                // Toggle Switch
                SizedBox(
                  height: 20,
                  child: Transform.scale(
                    scale: 0.65,
                    child: CupertinoSwitch(
                      value: banner.isActive,
                      activeTrackColor: const Color(0xFF059669),
                      onChanged: (_) => _toggleBannerStatus(banner),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0052FF)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit Banner',
                  onPressed: () => _openCreateBannerDialog(banner),
                ),
                const SizedBox(width: 6),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete Banner',
                  onPressed: () => _confirmDeleteBanner(banner),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannersEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x180052FF), blurRadius: 16, offset: Offset(0, 5)),
                ],
              ),
              child: const Center(
                child: Icon(Icons.view_carousel_rounded, size: 30, color: Color(0xFF0052FF)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No promotional banners yet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: const Text(
                'Create dynamic offers with headline, image & coupon codes that appear live in customer storefront header.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.35),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _openCreateBannerDialog(),
              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
              label: const Text('Create First Banner Offer', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052FF),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
              child: Column(
                children: [
                  // Section Switcher: Coupons vs Promotional Banners
                  _buildSectionSwitcher(),

                  // Active View
                  Expanded(
                    child: _selectedMainTab == 0
                        ? _buildCouponsSection(filtered)
                        : _buildPromotionalBannersSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
