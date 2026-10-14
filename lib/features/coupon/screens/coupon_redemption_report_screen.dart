import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/coupon_service.dart';

class CouponRedemptionReportScreen extends StatefulWidget {
  final CouponModel coupon;

  const CouponRedemptionReportScreen({
    super.key,
    required this.coupon,
  });

  @override
  State<CouponRedemptionReportScreen> createState() => _CouponRedemptionReportScreenState();
}

class _CouponRedemptionReportScreenState extends State<CouponRedemptionReportScreen> {
  final _couponService = CouponService();
  bool _isLoading = true;
  List<CouponRedemptionModel> _redemptions = [];

  @override
  void initState() {
    super.initState();
    _loadRedemptions();
  }

  Future<void> _loadRedemptions() async {
    setState(() => _isLoading = true);
    try {
      final list = await _couponService.getRedemptions(widget.coupon.id);
      if (mounted) {
        setState(() {
          _redemptions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load redemptions: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  double get _totalDiscountGiven => _redemptions.fold(0.0, (sum, e) => sum + e.discountAmount);
  double get _totalOrderValue => _redemptions.fold(0.0, (sum, e) => sum + e.billAmount);

  Widget _buildTopHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
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
                children: [
                  Text(
                    'Redemptions: ${widget.coupon.code}',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'Redemption log and revenue audit',
                    style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
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
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 17),
                tooltip: 'Refresh',
                onPressed: _loadRedemptions,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F4F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x30001C55),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052FF)))
                    : Column(
                        children: [
                          // Top Metrics Header
                          Container(
                            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(color: Color(0xFFE2E8F0), blurRadius: 4, offset: Offset(0, 1)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Total Used', style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_redemptions.length}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Discount', style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${_totalDiscountGiven.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Sales Generated', style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${_totalOrderValue.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                // Redemptions List
                Expanded(
                  child: _redemptions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              const Text(
                                'No redemptions yet',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 3),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Redemptions will appear here once cashiers apply this coupon to settled orders.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          itemCount: _redemptions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final r = _redemptions[index];
                            final dateStr = r.createdAt != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format(r.createdAt!)
                                : 'Recent';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0xFFF1F5F9), blurRadius: 3, offset: Offset(0, 1)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              r.orderId != null ? 'Order #${r.orderId}' : 'Bill Succeeded',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                                            ),
                                            Text(
                                              '• $dateStr',
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          r.customerPhone != null && r.customerPhone!.isNotEmpty
                                              ? 'Customer: ${r.customerName ?? ''} (${r.customerPhone})'
                                              : 'Cashier: ${r.cashierName.isNotEmpty ? r.cashierName : "Counter"}',
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '-₹${r.discountAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Bill: ₹${r.billAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
  }
}
