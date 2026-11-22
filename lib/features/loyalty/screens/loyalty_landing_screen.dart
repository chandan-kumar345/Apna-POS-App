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
import 'loyalty_program_details_screen.dart';
import 'loyalty_visit_made_screen.dart';

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
  int _desktopFilterIndex = 0; // 0: All, 1: Active, 2: Inactive, 3: Visit Made

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

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  void _navigateToEditProgram(LoyaltyProgramModel program) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLoyaltyProgramScreen(
          programToEdit: program,
          onSaved: () => _loadLoyaltyData(forceRefresh: true),
        ),
      ),
    );
  }

  void _navigateToVisitMade() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoyaltyVisitMadeScreen(
          companyName: _currentStoreName,
          companyLogo: _companyLogo,
          onCompleted: () => _loadLoyaltyData(forceRefresh: true),
        ),
      ),
    );
  }

  Future<void> _toggleProgramActive(LoyaltyProgramModel program, bool newValue) async {
    final ok = await _loyaltyService.updateProgramStatus(program.id, isActive: newValue);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'Program activated' : 'Program deactivated'),
            backgroundColor: newValue ? const Color(0xFF10B981) : Colors.black87,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadLoyaltyData(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteProgram(LoyaltyProgramModel program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Loyalty Program?', style: customerText(18, weight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${program.title}"? Customers will no longer earn or redeem rewards for this program.',
          style: customerText(14, color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: customerText(14, color: muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Program'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await _loyaltyService.deleteLoyaltyProgram(program.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Program "${program.title}" deleted successfully.'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadLoyaltyData(forceRefresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete program. Please try again.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return CustomerShell(
        header: _buildTopHeader(),
        body: _buildBody(),
        footer: _buildCreateProgramFooter(),
      );
    }
    return _buildDesktopWebLayout();
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

            // Section Header: Active Programs
            Text(
              'Active Programs (${activePrograms.isNotEmpty ? activePrograms.length : allPrograms.length})',
              style: customerText(14, weight: FontWeight.w700),
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

  // =========================================================================
  // DESKTOP & WEB LAYOUT
  // =========================================================================

  Widget _buildDesktopWebLayout() {
    if (_isLoading && _brandingData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF08435E)),
        ),
      );
    }

    final data = _brandingData ?? _loyaltyService.getDefaultLoyaltyBranding();
    final allPrograms = data.programs;

    // Filter according to _desktopFilterIndex: 0: All, 1: Active, 2: Inactive, 3: Visit Made
    final filteredPrograms = allPrograms.where((p) {
      if (_desktopFilterIndex == 1) return p.isActive;
      if (_desktopFilterIndex == 2) return !p.isActive;
      if (_desktopFilterIndex == 3) return p.type == LoyaltyType.visitMade;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Desktop Top Header
            _buildDesktopTopHeader(),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF08435E),
                onRefresh: () => _loadLoyaltyData(forceRefresh: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Metric Cards Row (4 cards)
                          _buildDesktopMetricCardsRow(data),
                          const SizedBox(height: 20),

                          // 2. Hero Banner Card
                          _buildDesktopHeroCard(),
                          const SizedBox(height: 24),

                          // 3. Section Header & Filter Tabs Row
                          _buildDesktopFilterHeader(allPrograms),
                          const SizedBox(height: 16),

                          // 4. Programs Grid or Empty State
                          if (filteredPrograms.isNotEmpty)
                            _buildDesktopProgramsGrid(filteredPrograms)
                          else
                            _buildDesktopEmptyState(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
              onPressed: widget.onBack,
              tooltip: 'Back to Dashboard',
            ),
            const SizedBox(width: 8),
          ],

          // Store Logo & Name
          InkWell(
            onTap: widget.onOpenDrawer,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SmoothBrandLogoWidget(
                  logoPath: _companyLogo,
                  companyName: _currentStoreName,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _currentStoreName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Loyalty Hub',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Cashback, Points & Automated Customer Retention',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),

          // Action 1: Visit Made Stamp Card
          OutlinedButton.icon(
            onPressed: _navigateToVisitMade,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F766E),
              side: const BorderSide(color: Color(0xFF99F6E4)),
              backgroundColor: const Color(0xFFF0FDFA),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.card_membership_rounded, size: 18, color: Color(0xFF0F766E)),
            label: const Text('Visit Stamp Card', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 10),

          // Action 3: Refresh Button
          IconButton(
            onPressed: () => _loadLoyaltyData(forceRefresh: true),
            tooltip: 'Refresh Programs',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
          ),
          const SizedBox(width: 8),

          // Action 4: + Create Loyalty Program
          ElevatedButton.icon(
            onPressed: _navigateToCreateProgram,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF08435E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Program', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMetricCardsRow(LoyaltyBrandingModel data) {
    final membersStr = NumberFormat.decimalPattern('en_IN').format(data.members);
    final cashbackStr = _currencyFormat.format(data.totalCashback);
    final redemptionsStr = NumberFormat.decimalPattern('en_IN').format(data.redemptions);
    final activeCount = data.programs.where((p) => p.isActive).length;

    return Row(
      children: [
        // 1. Members
        Expanded(
          child: _buildDesktopMetricTile(
            bgColor: const Color(0xFFE8F7F0),
            borderColor: const Color(0xFFC7EED8),
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'Total Members',
            value: membersStr,
            subtitle: 'Enrolled in loyalty',
          ),
        ),
        const SizedBox(width: 14),

        // 2. Total Cashback Given
        Expanded(
          child: _buildDesktopMetricTile(
            bgColor: const Color(0xFFF1EEFF),
            borderColor: const Color(0xFFDDD6FE),
            icon: Icons.currency_rupee_rounded,
            iconColor: const Color(0xFF8B5CF6),
            label: 'Total Cashback Given',
            value: cashbackStr,
            subtitle: 'Credited to customer wallets',
          ),
        ),
        const SizedBox(width: 14),

        // 3. Redemptions
        Expanded(
          child: _buildDesktopMetricTile(
            bgColor: const Color(0xFFFFF4E5),
            borderColor: const Color(0xFFFED7AA),
            icon: Icons.confirmation_number_outlined,
            iconColor: const Color(0xFFF59E0B),
            label: 'Total Redemptions',
            value: redemptionsStr,
            subtitle: 'Offers claimed at checkout',
          ),
        ),
        const SizedBox(width: 14),

        // 4. Active Programs
        Expanded(
          child: _buildDesktopMetricTile(
            bgColor: const Color(0xFFE0F2FE),
            borderColor: const Color(0xFFBAE6FD),
            icon: Icons.loyalty_rounded,
            iconColor: const Color(0xFF0284C7),
            label: 'Active Programs',
            value: '$activeCount / ${data.programs.length}',
            subtitle: 'Currently running live',
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopMetricTile({
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
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
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C8B5CF6),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFF59E0B),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Automated Cashback & Loyalty Engine',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Reward customers with instant or future cashback on every checkout. Cashbacks automatically credit to customer mobile numbers and drive repeat visits.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _navigateToCreateProgram,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text(
              'Add Program',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterHeader(List<LoyaltyProgramModel> allPrograms) {
    final activeCount = allPrograms.where((p) => p.isActive).length;
    final inactiveCount = allPrograms.where((p) => !p.isActive).length;
    final visitCount = allPrograms.where((p) => p.type == LoyaltyType.visitMade).length;

    final filterTabs = [
      {'label': 'All Programs', 'count': allPrograms.length},
      {'label': 'Active', 'count': activeCount},
      {'label': 'Inactive', 'count': inactiveCount},
      {'label': 'Visit Made', 'count': visitCount},
    ];

    return Row(
      children: [
        const Text(
          'Loyalty Programs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 20),

        // Filter tabs pills
        Wrap(
          spacing: 8,
          children: [
            for (int i = 0; i < filterTabs.length; i++)
              InkWell(
                onTap: () => setState(() => _desktopFilterIndex = i),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _desktopFilterIndex == i
                        ? const Color(0xFF08435E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _desktopFilterIndex == i
                          ? const Color(0xFF08435E)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filterTabs[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _desktopFilterIndex == i ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _desktopFilterIndex == i
                              ? Colors.white.withOpacity(0.25)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${filterTabs[i]['count']}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _desktopFilterIndex == i ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopProgramsGrid(List<LoyaltyProgramModel> programs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 224,
          ),
          itemCount: programs.length,
          itemBuilder: (ctx, i) => _buildDesktopProgramCard(programs[i]),
        );
      },
    );
  }

  Widget _buildDesktopProgramCard(LoyaltyProgramModel program) {
    final isPercent = program.cashbackType == 'percentage' || program.title.contains('%');
    final isVisitMade = program.type == LoyaltyType.visitMade;

    final iconBgColor = isVisitMade
        ? const Color(0xFFFEF3C7)
        : (isPercent ? const Color(0xFFE6F7F0) : const Color(0xFFF1EEFF));
    final iconColor = isVisitMade
        ? const Color(0xFFD97706)
        : (isPercent ? const Color(0xFF10B981) : const Color(0xFF8B5CF6));
    final iconData = isVisitMade
        ? Icons.card_membership_rounded
        : Icons.currency_rupee_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: program.isActive ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
          width: program.isActive ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon, Title, Active Badge, Switch Toggle
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Started: ${program.startedDate}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Active / Inactive Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: program.isActive ? const Color(0xFFE6F7F0) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  program.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: program.isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Switch Toggle
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: program.isActive,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) => _toggleProgramActive(program, val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Description
          Text(
            program.description.isNotEmpty
                ? program.description
                : 'Give cashback on orders to build loyal customers.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Row 3: Rule Pills
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildRuleChip(
                icon: Icons.percent_rounded,
                text: isPercent
                    ? '${program.cashbackPercentage.toStringAsFixed(0)}% Cashback'
                    : '₹${program.cashbackAmount.toStringAsFixed(0)} Cashback',
                color: const Color(0xFF0F766E),
                bg: const Color(0xFFF0FDFA),
              ),
              _buildRuleChip(
                icon: Icons.shopping_bag_outlined,
                text: 'Min ₹${program.minimumOrder.toStringAsFixed(0)}',
                color: const Color(0xFF0369A1),
                bg: const Color(0xFFF0F9FF),
              ),
              if (program.maximumCashback > 0)
                _buildRuleChip(
                  icon: Icons.shield_outlined,
                  text: 'Max ₹${program.maximumCashback.toStringAsFixed(0)}',
                  color: const Color(0xFF4338CA),
                  bg: const Color(0xFFEEF2FF),
                ),
              _buildRuleChip(
                icon: Icons.groups_outlined,
                text: program.eligibleCustomers,
                color: const Color(0xFF334155),
                bg: const Color(0xFFF8FAFC),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Row 4: Action Buttons (View Details, Edit, Delete)
          Row(
            children: [
              Text(
                'Validity: ${program.validity}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _navigateToEditProgram(program),
                tooltip: 'Edit Program',
                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
              ),
              IconButton(
                onPressed: () => _deleteProgram(program),
                tooltip: 'Delete Program',
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: () => _navigateToProgramDetails(program),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF08435E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleChip({
    required IconData icon,
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.loyalty_outlined, size: 40, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Loyalty Programs Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create your first cashback program or visit stamp card to start rewarding customers.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _navigateToCreateProgram,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF08435E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Loyalty Program', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

}
