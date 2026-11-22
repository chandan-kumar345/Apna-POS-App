import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../../campaign/mobile/campaign_style.dart';
import '../../campaign/mobile/customer_style.dart';
import 'create_loyalty_program_screen.dart';
import 'loyalty_performance_screen.dart';

class LoyaltyProgramDetailsScreen extends StatefulWidget {
  final LoyaltyProgramModel program;
  final VoidCallback? onProgramChanged;

  const LoyaltyProgramDetailsScreen({
    super.key,
    required this.program,
    this.onProgramChanged,
  });

  @override
  State<LoyaltyProgramDetailsScreen> createState() =>
      _LoyaltyProgramDetailsScreenState();
}

class _LoyaltyProgramDetailsScreenState
    extends State<LoyaltyProgramDetailsScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  late LoyaltyProgramModel _currentProgram;
  late bool _isActive;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _currentProgram = widget.program;
    _isActive = widget.program.isActive;
  }

  Future<void> _handleToggle(bool value) async {
    setState(() {
      _isToggling = true;
      _isActive = value;
    });

    final ok = await _loyaltyService.updateProgramStatus(
      _currentProgram.id,
      isActive: value,
    );

    if (mounted) {
      setState(() {
        _isToggling = false;
        if (ok) {
          _currentProgram = _currentProgram.copyWith(isActive: value);
          widget.onProgramChanged?.call();
        } else {
          _isActive = !value; // revert on failure
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Program activated successfully'
                : 'Program deactivated successfully',
          ),
          backgroundColor: value ? const Color(0xFF10B981) : Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Deactivate Program?',
          style: campaignText(18, weight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to deactivate "${_currentProgram.title}"? Customers will no longer earn or redeem cashback for this program.',
          style: campaignText(14, color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: campaignText(14, color: muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _handleToggle(false);
    }
  }

  void _showEligibleCustomersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_rounded, color: Color(0xFF08435E)),
                const SizedBox(width: 10),
                Text(
                  'Eligible Audience',
                  style: campaignText(18, weight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Targeting: ${_currentProgram.eligibleCustomers}',
                      style: campaignText(14, weight: FontWeight.w600, color: const Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This cashback program is applicable across ${_currentProgram.orderTypes.join(', ')} orders with minimum bill of ₹${_currentProgram.minimumOrder.toInt()}.',
              style: campaignText(13, color: muted),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      header: _buildTopHeader(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Status Card (Matching Screen 3)
            _buildProgramHeroCard(),
            const SizedBox(height: 14),

            // Program Details Card
            _buildProgramDetailsCard(),
            const SizedBox(height: 14),

            // Program Performance Card
            _buildProgramPerformanceCard(),
            const SizedBox(height: 16),

            // 4 Action Buttons Row (Edit, Reports, Customers, Deactivate)
            _buildActionButtonsRow(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Text(
            'Cashback Program',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // Top Hero Banner with Green rupee/exchange icon, title, Active badge, and Switch
  Widget _buildProgramHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F7F0), Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBCECD2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1210B981),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // White Circle with green currency exchange icon
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1010B981),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Title, Subtitle, Active Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentProgram.title,
                  style: campaignText(15, weight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentProgram.earningRule.isNotEmpty
                      ? _currentProgram.earningRule
                      : _currentProgram.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: campaignText(12, color: muted),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _isActive
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _isActive
                          ? const Color(0xFF065F46)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Green Toggle Switch
          Switch.adaptive(
            value: _isActive,
            onChanged: _isToggling ? null : _handleToggle,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  // Program Details Card with multi-layer realistic shadows
  Widget _buildProgramDetailsCard() {
    final cashbackText = _currentProgram.cashbackType == 'percentage'
        ? '${_currentProgram.cashbackPercentage.toStringAsFixed(0)}% of order value'
        : '₹${_currentProgram.cashbackAmount.toStringAsFixed(0)} per order';

    final minOrderText = '₹${_currentProgram.minimumOrder.toInt()}';
    final maxCashbackText = '₹${_currentProgram.maximumCashback.toInt()} per order';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F2942),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program Details',
            style: campaignText(15, weight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.local_offer_outlined,
            'Program Type',
            'Cashback',
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            Icons.percent_rounded,
            'Cashback',
            cashbackText,
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            Icons.shopping_cart_outlined,
            'Minimum Order',
            minOrderText,
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            Icons.account_balance_wallet_outlined,
            'Maximum Cashback',
            maxCashbackText,
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            Icons.calendar_today_outlined,
            'Validity',
            _currentProgram.validity.isNotEmpty ? _currentProgram.validity : 'Continuous',
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            Icons.people_outline_rounded,
            'Eligible Customers',
            _currentProgram.eligibleCustomers,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF08435E)),
        const SizedBox(width: 10),
        Text(label, style: campaignText(13, color: muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: campaignText(13, weight: FontWeight.w600, color: ink),
          ),
        ),
      ],
    );
  }

  // Program Performance Card with 3 metric boxes: Orders, Cashback Given, Redemption Rate
  Widget _buildProgramPerformanceCard() {
    final ordersCount = _currentProgram.ordersCount;
    final cashbackGiven = _currencyFormat.format(_currentProgram.cashbackGiven);
    final redemptionRate = '${_currentProgram.redemptionRate.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F2942),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program Performance',
            style: campaignText(15, weight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.people_outline_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFE8F7F0),
                  borderColor: const Color(0xFFC7EED8),
                  label: 'Orders',
                  value: NumberFormat.decimalPattern('en_IN').format(ordersCount),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.currency_rupee_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFF1EEFF),
                  borderColor: const Color(0xFFDDD6FE),
                  label: 'Cashback Given',
                  value: cashbackGiven,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFE8F7F0),
                  borderColor: const Color(0xFFC7EED8),
                  label: 'Redemption Rate',
                  value: redemptionRate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2942),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: campaignText(10, color: muted, weight: FontWeight.w500),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: campaignText(13, weight: FontWeight.w800, color: ink),
          ),
        ],
      ),
    );
  }

  // 4 Action Buttons Row: Edit Program, View Reports, Eligible Customers, Deactivate
  Widget _buildActionButtonsRow() {
    return Row(
      children: [
        // 1. Edit Program
        Expanded(
          child: _buildActionButton(
            icon: Icons.campaign_outlined,
            label: 'Edit\nProgram',
            color: ink,
            onTap: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateLoyaltyProgramScreen(
                    programToEdit: _currentProgram,
                    onSaved: () => widget.onProgramChanged?.call(),
                  ),
                ),
              );
              if (updated == true && mounted) {
                widget.onProgramChanged?.call();
                Navigator.pop(context);
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // 2. View Reports
        Expanded(
          child: _buildActionButton(
            icon: Icons.bar_chart_rounded,
            label: 'View\nReports',
            color: ink,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoyaltyPerformanceScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // 3. Eligible Customers
        Expanded(
          child: _buildActionButton(
            icon: Icons.group_outlined,
            label: 'Eligible\nCustomers',
            color: ink,
            onTap: _showEligibleCustomersSheet,
          ),
        ),
        const SizedBox(width: 8),

        // 4. Deactivate
        Expanded(
          child: _buildActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Deactivate',
            color: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
            onTap: _confirmDeactivate,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? bgColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor ?? const Color(0xFFE2EAF2),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F2942),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
