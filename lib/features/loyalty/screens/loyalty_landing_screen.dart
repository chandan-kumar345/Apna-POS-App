import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../../../core/widgets/pos_screen_top_header.dart';
import '../../campaign/mobile/campaign_style.dart';
import '../../campaign/mobile/customer_style.dart';
import '../../notifications/screens/notifications_screen.dart';
import 'create_loyalty_program_screen.dart';
import 'loyalty_performance_screen.dart';
import 'loyalty_program_details_screen.dart';

class LoyaltyLandingScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onOpenDrawer;

  const LoyaltyLandingScreen({
    super.key,
    this.onBack,
    this.onOpenDrawer,
  });

  @override
  State<LoyaltyLandingScreen> createState() => _LoyaltyLandingScreenState();
}

class _LoyaltyLandingScreenState extends State<LoyaltyLandingScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  final DatabaseService _db = DatabaseService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool _isLoading = false;
  String? _errorMessage;
  LoyaltyBrandingModel? _brandingData;

  @override
  void initState() {
    super.initState();
    _brandingData = _loyaltyService.cachedBranding;
    _loadLoyaltyData();
  }

  Future<void> _loadLoyaltyData({bool forceRefresh = false}) async {
    if (_brandingData == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _loyaltyService.fetchLoyaltyPrograms(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _brandingData = data;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted && _brandingData == null) {
        setState(() {
          _errorMessage = 'Unable to load loyalty programs. Please check connection and retry.';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCreateProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLoyaltyProgramScreen(
          onSaved: () => _loadLoyaltyData(forceRefresh: true),
        ),
      ),
    );
  }

  void _navigateToProgramDetails(LoyaltyProgramModel program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoyaltyProgramDetailsScreen(
          program: program,
          onProgramChanged: () => _loadLoyaltyData(forceRefresh: true),
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

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  String get _currentStoreName {
    final store = _db.restaurant?.name.trim();
    if (store != null && store.isNotEmpty) return store;
    final comp = _brandingData?.companyName.trim();
    if (comp != null && comp.isNotEmpty) return comp;
    return 'Pizza 47';
  }

  String get _companyLogo {
    return _db.companyLogoPath ?? _brandingData?.companyLogo ?? '';
  }

  Widget _businessLogo(String logo, String business) {
    if (logo.startsWith('http')) {
      return Image.network(
        logo,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brand(business),
      );
    }
    if (logo.startsWith('assets/')) {
      return Image.asset(
        logo,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brand(business),
      );
    }
    if (!kIsWeb && logo.isNotEmpty) {
      try {
        final file = File(logo);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _brand(business),
          );
        }
      } catch (_) {}
    }
    return _brand(business);
  }

  Widget _brand(String business) => Container(
        color: const Color(0xFF13455A),
        alignment: Alignment.center,
        child: Text(
          business.trim().isEmpty
              ? 'AP'
              : business
                  .trim()
                  .split(RegExp(r'\s+'))
                  .take(2)
                  .map((word) => word[0])
                  .join()
                  .toUpperCase(),
          style: customerText(16, color: Colors.white, weight: FontWeight.w800),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      header: _buildTopHeader(),
      body: _buildBody(),
      footer: _buildCreateProgramFooter(),
    );
  }

  // POS Screen Top Header: Circular Brand Logo + Store badge (opens Sidebar on tap)
  Widget _buildTopHeader() {
    return PosScreenTopHeader(
      onLogoTap: widget.onOpenDrawer,
      onStoreTap: widget.onOpenDrawer,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _brandingData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _brandingData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: customerText(13, color: muted),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => _loadLoyaltyData(forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _brandingData ?? _loyaltyService.getDefaultLoyaltyBranding();
    final allPrograms = data.programs;
    final activePrograms = allPrograms.where((p) => p.isActive).toList();

    return RefreshIndicator(
      onRefresh: () => _loadLoyaltyData(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Subtitle with smaller fonts
            Text(
              'Loyalty Program',
              style: customerText(19, weight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              'Build customer loyalty with cashback, points & rewards.',
              style: customerText(12, color: muted, weight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Hero Card: Trophy + "Cashback Rewards" (compact size)
            _buildHeroCard(),
            const SizedBox(height: 12),

            // 3 Stat Cards Row: Members, Total Cashback, Redemptions (compact size)
            _buildMetricCardsRow(data),
            const SizedBox(height: 16),

            // Section Header: Active Programs (2) & View All ->
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Programs (${activePrograms.isNotEmpty ? activePrograms.length : allPrograms.length})',
                  style: customerText(14, weight: FontWeight.w700),
                ),
                InkWell(
                  onTap: _navigateToPerformance,
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: customerText(
                          11,
                          weight: FontWeight.w600,
                          color: const Color(0xFF08435E),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Color(0xFF08435E),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Active Programs List
            if (activePrograms.isNotEmpty)
              for (final p in activePrograms) _buildProgramCard(p)
            else if (allPrograms.isNotEmpty)
              for (final p in allPrograms) _buildProgramCard(p)
            else
              _buildEmptyProgramsCard(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Hero Card with Trophy graphic and "Cashback Rewards" (smaller & compact)
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEDE9FE),
            Color(0xFFF5F3FF),
            Color(0xFFFAF5FF),
          ],
        ),
        border: Border.all(color: const Color(0xFFDDD6FE)),
        boxShadow: const [studioShadow],
      ),
      child: Row(
        children: [
          // Trophy Graphic with sparkles
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFF59E0B),
                  size: 26,
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cashback Rewards',
                  style: customerText(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Give instant or future cashback on every order.',
                  style: customerText(11, color: muted, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3 Metric Cards Row: Members, Total Cashback, Redemptions (compact size)
  Widget _buildMetricCardsRow(LoyaltyBrandingModel data) {
    final membersStr = NumberFormat.decimalPattern('en_IN').format(data.members);
    final cashbackStr = _currencyFormat.format(data.totalCashback);
    final redemptionsStr = NumberFormat.decimalPattern('en_IN').format(data.redemptions);

    return Row(
      children: [
        // Card 1: Members (Mint)
        Expanded(
          child: _buildMetricTile(
            bgColor: const Color(0xFFE8F7F0),
            borderColor: const Color(0xFFC7EED8),
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'Members',
            value: membersStr,
          ),
        ),
        const SizedBox(width: 7),

        // Card 2: Total Cashback (Lavender)
        Expanded(
          child: _buildMetricTile(
            bgColor: const Color(0xFFF1EEFF),
            borderColor: const Color(0xFFDDD6FE),
            icon: Icons.currency_rupee_rounded,
            iconColor: const Color(0xFF8B5CF6),
            label: 'Total Cashback',
            value: cashbackStr,
          ),
        ),
        const SizedBox(width: 7),

        // Card 3: Redemptions (Soft Amber)
        Expanded(
          child: _buildMetricTile(
            bgColor: const Color(0xFFFFF4E5),
            borderColor: const Color(0xFFFED7AA),
            icon: Icons.confirmation_number_outlined,
            iconColor: const Color(0xFFF59E0B),
            label: 'Redemptions',
            value: redemptionsStr,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: customerText(10, color: muted, weight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: customerText(14, weight: FontWeight.w800, color: customerInk),
          ),
        ],
      ),
    );
  }

  // Active Program Card (compact size)
  Widget _buildProgramCard(LoyaltyProgramModel program) {
    final isPercent = program.cashbackType == 'percentage' ||
        program.title.contains('%');
    final iconBgColor = isPercent ? const Color(0xFFE6F7F0) : const Color(0xFFF1EEFF);
    final iconColor = isPercent ? const Color(0xFF10B981) : const Color(0xFF8B5CF6);

    return InkWell(
      onTap: () => _navigateToProgramDetails(program),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [studioShadow],
        ),
        child: Row(
          children: [
            // Icon in circle
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.currency_rupee_rounded,
                color: iconColor,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),

            // Program Title, Description, Started Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.title,
                    style: customerText(13, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    program.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: customerText(11, color: muted, weight: FontWeight.w400),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Started: ${program.startedDate}',
                        style: customerText(10, color: muted, weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Active badge + chevron right
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProgramsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.loyalty_outlined, size: 36, color: muted),
            const SizedBox(height: 6),
            Text(
              'No active programs yet',
              style: customerText(13, weight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              'Create your first cashback program to reward customers.',
              textAlign: TextAlign.center,
              style: customerText(11, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  // "+ Create Loyalty Program" Docked Bottom Action Button
  Widget _buildCreateProgramFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: InkWell(
        onTap: _navigateToCreateProgram,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF072D42), Color(0xFF031622)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Create Loyalty Program',
                style: customerText(14, weight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
