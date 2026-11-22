import 'package:flutter/foundation.dart';
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
    return _buildDesktopLayout();
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

  // =========================================================================
  // DESKTOP & WEB LAYOUT
  // =========================================================================

  void _navigateToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLoyaltyProgramScreen(
          programToEdit: _currentProgram,
          onSaved: () {
            widget.onProgramChanged?.call();
            setState(() {
              // Reloaded through parent callback
            });
          },
        ),
      ),
    );
  }

  void _navigateToPerformance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoyaltyPerformanceScreen(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final isPercent = _currentProgram.cashbackType == 'percentage' ||
        _currentProgram.title.contains('%');
    final rateStr = isPercent
        ? '${_currentProgram.cashbackPercentage.toStringAsFixed(0)}% Cashback'
        : '₹${_currentProgram.cashbackAmount.toStringAsFixed(0)} Cashback';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentProgram.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Started: ${_currentProgram.startedDate} • Status: ${_isActive ? "Active" : "Inactive"}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          // Active Switch
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              _isToggling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    )
                  : Switch(
                      value: _isActive,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        if (!val) {
                          _confirmDeactivate();
                        } else {
                          _handleToggle(true);
                        }
                      },
                    ),
            ],
          ),
          const SizedBox(width: 12),

          // Edit Program Button
          OutlinedButton.icon(
            onPressed: _navigateToEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF08435E),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit Program', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(width: 8),

          // Analytics Button
          OutlinedButton.icon(
            onPressed: _navigateToPerformance,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F766E),
              side: const BorderSide(color: Color(0xFF99F6E4)),
              backgroundColor: const Color(0xFFF0FDFA),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.insights_rounded, size: 16, color: Color(0xFF0F766E)),
            label: const Text('Performance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 860;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Hero Status + Rules Details + Actions
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDesktopProgramHero(rateStr),
                              const SizedBox(height: 16),
                              _buildDesktopRulesCard(),
                              const SizedBox(height: 16),
                              _buildDesktopActionRow(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Right Column: Performance Analytics + WhatsApp Preview
                        SizedBox(
                          width: 380,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDesktopPerformanceCard(),
                              const SizedBox(height: 16),
                              _buildDesktopMessagePreview(),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDesktopProgramHero(rateStr),
                        const SizedBox(height: 14),
                        _buildDesktopRulesCard(),
                        const SizedBox(height: 14),
                        _buildDesktopPerformanceCard(),
                        const SizedBox(height: 14),
                        _buildDesktopMessagePreview(),
                        const SizedBox(height: 16),
                        _buildDesktopActionRow(),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopProgramHero(String rateStr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: Color(0xFF10B981),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _currentProgram.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isActive ? const Color(0xFFE6F7F0) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentProgram.description.isNotEmpty
                      ? _currentProgram.description
                      : 'Give cashback on orders to build loyal customers.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Column(
              children: [
                const Text(
                  'Cashback Rate',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6D28D9)),
                ),
                const SizedBox(height: 2),
                Text(
                  rateStr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5B21B6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRulesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, size: 18, color: Color(0xFF08435E)),
              SizedBox(width: 8),
              Text(
                'Program Rules & Configuration',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailTile(
                  title: 'Minimum Order',
                  value: '₹${_currentProgram.minimumOrder.toInt()}',
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailTile(
                  title: 'Max Cashback',
                  value: '₹${_currentProgram.maximumCashback.toInt()}',
                  icon: Icons.shield_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailTile(
                  title: 'Validity',
                  value: _currentProgram.validity,
                  icon: Icons.event_available_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Eligible Audience',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _showEligibleCustomersSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 15, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Text(
                              _currentProgram.eligibleCustomers,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF16A34A)),
                          ],
                        ),
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
                      'Applicable Order Types',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final type in _currentProgram.orderTypes)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPerformanceCard() {
    final distributedStr = _currencyFormat.format(_currentProgram.cashbackGiven);
    final ordersCount = _currentProgram.ordersCount;
    final rate = _currentProgram.redemptionRate;
    final membersCount = _currentProgram.membersCount > 0 ? _currentProgram.membersCount : _currentProgram.ordersCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Performance Metrics',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: _navigateToPerformance,
                child: const Text(
                  'Full Report →',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF08435E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricMini(
                  label: 'Members Active',
                  value: '$membersCount',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMini(
                  label: 'Cashback Issued',
                  value: distributedStr,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricMini(
                  label: 'Total Orders',
                  value: '$ordersCount',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMini(
                  label: 'Redemption Rate',
                  value: '${rate.toStringAsFixed(1)}%',
                  color: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMini({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMessagePreview() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text(
                'Customer Notification Preview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _currentProgram.messageTemplate.isNotEmpty
                  ? _currentProgram.messageTemplate
                  : 'Hi {{name}}! Earn cashback on your next order.',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF1E293B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActionRow() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _navigateToEdit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF08435E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit Program', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _showEligibleCustomersSheet,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.people_outline_rounded, size: 16),
          label: const Text('Audience Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _navigateToPerformance,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.insights_rounded, size: 16),
          label: const Text('View Analytics', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _isActive ? _confirmDeactivate : () => _handleToggle(true),
          style: OutlinedButton.styleFrom(
            foregroundColor: _isActive ? Colors.redAccent : const Color(0xFF10B981),
            side: BorderSide(color: _isActive ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
            backgroundColor: _isActive ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(_isActive ? Icons.power_settings_new_rounded : Icons.check_circle_outline, size: 16),
          label: Text(
            _isActive ? 'Deactivate Program' : 'Activate Program',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
