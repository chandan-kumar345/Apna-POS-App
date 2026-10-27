import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';
import '../../../../core/database/database_service.dart';

class CampaignDashboardView extends StatefulWidget {
  final VoidCallback onCreateCampaign;
  final VoidCallback onCreateAutoCampaign;
  final ValueChanged<CampaignModel> onSelectCampaign;

  const CampaignDashboardView({
    super.key,
    required this.onCreateCampaign,
    required this.onCreateAutoCampaign,
    required this.onSelectCampaign,
  });

  @override
  State<CampaignDashboardView> createState() => _CampaignDashboardViewState();
}

class _CampaignDashboardViewState extends State<CampaignDashboardView> {
  final CampaignService _campaignService = CampaignService();
  final DatabaseService _db = DatabaseService();

  String _selectedTab = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  CampaignStatsModel _stats = const CampaignStatsModel();
  List<CampaignModel> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await _campaignService.fetchDashboardStats();
    final list = await _campaignService.fetchCampaigns(
      status: _selectedTab == 'All' || _selectedTab == 'Marketing' || _selectedTab == 'Utility'
          ? null
          : _selectedTab,
      type: _selectedTab == 'Marketing' || _selectedTab == 'Utility' ? _selectedTab : null,
      search: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _stats = stats;
        _campaigns = list;
        _isLoading = false;
      });
    }
  }

  void _onTabChanged(String tab) {
    setState(() => _selectedTab = tab);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final restName = _db.restaurant?.name.isNotEmpty == true ? _db.restaurant!.name : 'Pizza 47';

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Top Navigation / Brand Bar
          _buildBrandHeader(restName),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title & Header Actions
                  _buildPageHeader(),
                  const SizedBox(height: 22),

                  // 4 Stat Metric Cards
                  _buildStatsRow(),
                  const SizedBox(height: 24),

                  // Filter Tabs & Search
                  _buildFilterTabs(),
                  const SizedBox(height: 16),

                  // Campaign Table
                  _buildCampaignTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(String restName) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Center(
                  child: Text('🍕', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                restName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF16A34A)),
                    SizedBox(width: 5),
                    Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 22),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFE2E8F0),
                child: Icon(Icons.person, color: Color(0xFF64748B), size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Campaigns',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Reach your customers with offers, updates and announcements.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: widget.onCreateCampaign,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Campaign', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF95B1C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: widget.onCreateAutoCampaign,
                icon: const Icon(Icons.auto_mode_rounded, size: 18),
                label: const Text('Create Auto Campaign', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF95B1C),
                  side: const BorderSide(color: Color(0xFFF95B1C), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (3 * 16)) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              title: 'Total Campaigns',
              value: '${_stats.totalCampaigns}',
              icon: Icons.campaign_rounded,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Messages Sent',
              value: _formatCount(_stats.messagesSent),
              icon: Icons.forum_rounded,
              iconColor: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Delivery Rate',
              value: '${_stats.deliveryRate.toStringAsFixed(1)}%',
              icon: Icons.verified_user_rounded,
              iconColor: const Color(0xFF0D9488),
              bgColor: const Color(0xFFF0FDFA),
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Total Spent',
              value: '₹${_stats.totalSpent.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required double width,
  }) {
    return Container(
      width: width.clamp(200.0, 360.0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'key': 'All', 'label': 'All (${_stats.allCount})'},
      {'key': 'Marketing', 'label': 'Marketing (${_stats.marketingCount})'},
      {'key': 'Utility', 'label': 'Utility (${_stats.utilityCount})'},
      {'key': 'Scheduled', 'label': 'Scheduled (${_stats.scheduledCount})'},
      {'key': 'Running', 'label': 'Running (${_stats.runningCount})'},
      {'key': 'Completed', 'label': 'Completed (${_stats.completedCount})'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _onTabChanged(tab['key']!),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  tab['label']!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCampaignTable() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFF95B1C)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Table Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: const Color(0xFFF8FAFC),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Campaign Name', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('Type', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('Audience', style: _headerStyle)),
                  Expanded(flex: 1, child: Text('Sent', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('Delivery Rate', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
                  SizedBox(width: 48, child: Text('Actions', style: _headerStyle)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Table Data Rows
            if (_campaigns.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text('No campaigns found in this view', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              )
            else
              ..._campaigns.map((c) => _buildCampaignRow(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignRow(CampaignModel c) {
    return InkWell(
      onTap: () => widget.onSelectCampaign(c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // Campaign Name
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('🍕', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          c.campaignId,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Type
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.isMarketing ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    c.isMarketing ? 'Marketing' : 'Utility',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.isMarketing ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ),

            // Audience
            Expanded(
              flex: 2,
              child: Text(
                c.audience.groupName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              ),
            ),

            // Sent
            Expanded(
              flex: 1,
              child: Text(
                c.stats.messagesSent > 0 ? _formatCount(c.stats.messagesSent) : '-',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ),

            // Delivery Rate
            Expanded(
              flex: 2,
              child: Text(
                c.stats.deliveryRate > 0 ? '${c.stats.deliveryRate.toStringAsFixed(0)}%' : '-',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ),

            // Status Badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(c.status),
              ),
            ),

            // Actions Menu
            SizedBox(
              width: 48,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
                onSelected: (val) {
                  if (val == 'view') widget.onSelectCampaign(c);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'view', child: Text('View Details')),
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(
                    value: 'pause',
                    child: Text(c.isRunning ? 'Pause Campaign' : 'Resume Campaign'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    bool hasDot = false;

    switch (status.toLowerCase()) {
      case 'running':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        label = 'Running';
        hasDot = true;
        break;
      case 'scheduled':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        label = 'Scheduled';
        hasDot = true;
        break;
      case 'completed':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        label = 'Completed';
        hasDot = true;
        break;
      case 'draft':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'Draft';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDot) ...[
            CircleAvatar(radius: 3.5, backgroundColor: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  String _formatCount(int num) {
    if (num >= 1000) {
      final k = (num / 1000).toStringAsFixed(1);
      return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}k';
    }
    return '$num';
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
  );
}
