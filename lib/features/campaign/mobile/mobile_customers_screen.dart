import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/customer_service.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../models/campaign_models.dart';
import '../services/campaign_service.dart';
import 'campaign_style.dart';
import 'create_customer_group_screen.dart';
import 'customer_group_details_screen.dart';
import 'mobile_campaign_data.dart';

class MobileCustomersScreen extends StatefulWidget {
  final CampaignOptions? options;
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToCampaigns;

  const MobileCustomersScreen({
    super.key,
    this.options,
    this.onBack,
    this.onNavigateToCampaigns,
  });

  @override
  State<MobileCustomersScreen> createState() => _MobileCustomersScreenState();
}

class _MobileCustomersScreenState extends State<MobileCustomersScreen> {
  final CustomerService _customerService = CustomerService();
  final CampaignService _campaignService = CampaignService();

  final TextEditingController _searchController = TextEditingController();

  int _selectedTab = 0; // 0: Customers, 1: Groups
  String _selectedFilter = 'all'; // 'all', 'members', 'vip', 'inactive'

  bool _loading = false;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _groups = [];

  // Metrics
  int _totalCustomers = 12480;
  int _activeCustomers = 9860;
  int _loyaltyMembers = 3420;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final fetchedGroups = await _campaignService.fetchAudienceGroups();
      final fetchedCust = await _customerService.fetchCustomers(limit: 40);

      if (mounted) {
        setState(() {
          if (fetchedGroups.isNotEmpty) {
            _groups = fetchedGroups
                .map((g) => {
                      'id': g.id,
                      'name': g.name,
                      'count': g.count > 0 ? g.count : g.totalNumbers,
                      'description': g.description,
                      'createdAt': g.createdAt?.toIso8601String(),
                    })
                .toList();
          } else {
            _groups = _defaultGroups();
          }

          if (fetchedCust.isNotEmpty) {
            _customers = fetchedCust.map((c) {
              String tag = 'Member';
              if (c.totalSpent > 20000) {
                tag = 'VIP';
              } else if (c.totalOrders <= 1) {
                tag = 'New';
              } else if (c.totalOrders == 0) {
                tag = 'Inactive';
              }

              return {
                'id': c.id,
                'name': c.name,
                'phone': c.phone,
                'tag': tag,
                'totalSpend': c.totalSpent,
                'lastVisit': c.lastVisit != null
                    ? _formatDate(c.lastVisit!)
                    : '20 Nov 2026',
              };
            }).toList();
          } else {
            _customers = _defaultCustomers();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _groups = _defaultGroups();
          _customers = _defaultCustomers();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '20 Nov 2026';
    return DateFormat('d MMM yyyy').format(parsed);
  }

  List<Map<String, dynamic>> _defaultGroups() => [
        {
          'id': 'grp_1',
          'name': 'Pizza Lovers',
          'count': 2480,
          'icon': Icons.local_pizza_outlined,
          'bgColor': const Color(0xFFF3EBFF),
          'iconColor': const Color(0xFF7C3AED),
          'description':
              'Customers who frequently order pizza and are interested in new offers.',
          'createdDate': '12 Oct 2026',
        },
        {
          'id': 'grp_2',
          'name': 'VIP Customers',
          'count': 860,
          'icon': Icons.workspace_premium_outlined,
          'bgColor': const Color(0xFFFEF3C7),
          'iconColor': const Color(0xFFD97706),
          'description': 'High value patrons with lifetime spend above ₹20,000.',
          'createdDate': '15 Oct 2026',
        },
        {
          'id': 'grp_3',
          'name': 'Festive Offers',
          'count': 1240,
          'icon': Icons.card_giftcard_outlined,
          'bgColor': const Color(0xFFDCFCE7),
          'iconColor': const Color(0xFF16A34A),
          'description': 'Customers opted into festival discounts and seasonal treats.',
          'createdDate': '28 Oct 2026',
        },
        {
          'id': 'grp_4',
          'name': 'Discount Club',
          'count': 980,
          'icon': Icons.local_offer_outlined,
          'bgColor': const Color(0xFFE0F2FE),
          'iconColor': const Color(0xFF0284C7),
          'description': 'Members who love weekly coupons and flash vouchers.',
          'createdDate': '05 Nov 2026',
        },
      ];

  List<Map<String, dynamic>> _defaultCustomers() => [
        {
          'name': 'Rohit Sharma',
          'phone': '+91 98765 43210',
          'tag': 'VIP',
          'totalSpend': 24560,
          'lastVisit': '21 Nov 2026',
        },
        {
          'name': 'Ananya Patel',
          'phone': '+91 91234 56780',
          'tag': 'Member',
          'totalSpend': 12340,
          'lastVisit': '20 Nov 2026',
        },
        {
          'name': 'Vikram Khanna',
          'phone': '+91 99887 66554',
          'tag': 'New',
          'totalSpend': 3280,
          'lastVisit': '19 Nov 2026',
        },
        {
          'name': 'Priya Mehta',
          'phone': '+91 98765 11223',
          'tag': 'Member',
          'totalSpend': 18900,
          'lastVisit': '18 Nov 2026',
        },
        {
          'name': 'Aman Kumar',
          'phone': '+91 97654 32109',
          'tag': 'Inactive',
          'totalSpend': 0,
          'lastVisit': '10 Oct 2026',
        },
        {
          'name': 'Sneha Kulkarni',
          'phone': '+91 98220 12345',
          'tag': 'VIP',
          'totalSpend': 21400,
          'lastVisit': '17 Nov 2026',
        },
        {
          'name': 'Karan Joshi',
          'phone': '+91 97110 54321',
          'tag': 'Member',
          'totalSpend': 9450,
          'lastVisit': '16 Nov 2026',
        },
      ];

  void _openCreateGroup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateCustomerGroupScreen(
          options: widget.options,
          onGroupCreated: _loadData,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _openGroupDetails(Map<String, dynamic> group) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerGroupDetailsScreen(
          group: group,
          options: widget.options,
          onGroupUpdated: _loadData,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Add Customer', style: campaignText(17, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: campaignInput(hint: 'Customer Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: campaignInput(hint: 'Mobile Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: campaignText(13, color: muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: teal),
            onPressed: () {
              final n = nameCtrl.text.trim();
              final p = phoneCtrl.text.trim();
              if (n.isNotEmpty && p.isNotEmpty) {
                setState(() {
                  _customers.insert(0, {
                    'name': n,
                    'phone': p,
                    'tag': 'New',
                    'totalSpend': 0,
                    'lastVisit': 'Today',
                  });
                  _totalCustomers++;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Customer "$n" added')),
                );
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CampaignShell(
      header: _buildTopHeader(),
      body: _buildBody(),
      footer: _buildFooterNavigation(),
    );
  }

  Widget _buildTopHeader() {
    final businessName = widget.options?.business ?? 'Pizza 47';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          // APNA POS brand badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2C3F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4D7287)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'APNA POS',
                  style: campaignText(
                    12,
                    color: const Color(0xFFF8FAFC),
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Business dropdown pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF244B61),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4D7081)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  businessName,
                  style: campaignText(
                    14,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
          const Spacer(),

          // Notification Bell
          Stack(
            children: [
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF234157),
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final fmt = NumberFormat.decimalPattern('en_IN');

    // Customer filters
    final filteredCustomers = _customers.where((c) {
      final query = _searchController.text.trim().toLowerCase();
      final name = c['name'].toString().toLowerCase();
      final phone = c['phone'].toString();

      final matchesQuery = query.isEmpty || name.contains(query) || phone.contains(query);
      if (!matchesQuery) return false;

      final tag = (c['tag'] ?? '').toString().toLowerCase();
      switch (_selectedFilter) {
        case 'members':
          return tag == 'member';
        case 'vip':
          return tag == 'vip';
        case 'inactive':
          return tag == 'inactive';
        default:
          return true;
      }
    }).toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
            children: [
              // Title & Subtitle + Add icon button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customers', style: campaignText(28, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'Manage customers, groups, loyalty & engagement.',
                          style: campaignText(13, color: muted, weight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showAddCustomerDialog,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderBlue),
                        boxShadow: const [studioShadow],
                      ),
                      child: const Icon(
                        Icons.person_add_alt_outlined,
                        color: teal,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3 Stat Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _metricStatCard(
                      label: 'Total Customers',
                      value: fmt.format(_totalCustomers),
                      icon: Icons.people_alt_outlined,
                      bgColor: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricStatCard(
                      label: 'Active Customers',
                      value: fmt.format(_activeCustomers),
                      icon: Icons.person_outline_rounded,
                      bgColor: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricStatCard(
                      label: 'Loyalty Members',
                      value: fmt.format(_loyaltyMembers),
                      icon: Icons.workspace_premium_outlined,
                      bgColor: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Segmented Switcher / Pill Tabs: [Customers] [Groups]
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3F7),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _tabPill(
                        index: 0,
                        icon: Icons.person_outline_rounded,
                        label: 'Customers',
                      ),
                    ),
                    Expanded(
                      child: _tabPill(
                        index: 1,
                        icon: Icons.grid_view_rounded,
                        label: 'Groups',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: campaignText(13),
                      decoration: campaignInput(hint: 'Search by name, mobile or group...').copyWith(
                        prefixIcon: const Icon(Icons.search_rounded, color: ink, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      // Filter modal or toggle
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderBlue),
                        boxShadow: const [studioShadow],
                      ),
                      child: const Icon(Icons.tune_rounded, color: ink, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Customer Groups Horizontal Section
              Row(
                children: [
                  Text(
                    'Customer Groups',
                    style: campaignText(16, weight: FontWeight.w800),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: campaignText(13, color: teal, weight: FontWeight.w700),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_rounded, color: teal, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _groups.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    if (i == _groups.length) {
                      return _addGroupCard();
                    }
                    final g = _groups[i];
                    return _groupCardItem(g);
                  },
                ),
              ),
              const SizedBox(height: 14),

              if (_selectedTab == 0) ...[
                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All (12.4K)'),
                      _filterChip('members', 'Members (3.4K)'),
                      _filterChip('vip', 'VIP (860)'),
                      _filterChip('inactive', 'Inactive (120)'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                if (_loading) const LinearProgressIndicator(minHeight: 2),

                // Customer List
                for (final c in filteredCustomers) _customerTile(c),
              ] else ...[
                // Full Groups View when Groups tab is selected
                Row(
                  children: [
                    Text(
                      'All Groups (${_groups.length})',
                      style: campaignText(15, weight: FontWeight.w700),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Group'),
                      onPressed: _openCreateGroup,
                    ),
                  ],
                ),
                for (final g in _groups) _fullGroupTile(g),
              ],
            ],
          ),
        ),

        // Floating Action Button (+)
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: teal,
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.person_add_alt_outlined, color: teal),
                        title: Text('Add New Customer', style: campaignText(14, weight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAddCustomerDialog();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.group_add_outlined, color: teal),
                        title: Text('Create Customer Group', style: campaignText(14, weight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openCreateGroup();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _metricStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
        boxShadow: const [studioShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: campaignText(11.5, color: muted, weight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: campaignText(19, weight: FontWeight.w800, color: ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabPill({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: teal.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? Colors.white : ink,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: campaignText(
                13,
                color: isSelected ? Colors.white : ink,
                weight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupCardItem(Map<String, dynamic> g) {
    final fmt = NumberFormat.decimalPattern('en_IN');
    final count = g['count'] ?? 100;
    final name = g['name'] ?? 'Group';
    final icon = (g['icon'] as IconData?) ?? Icons.groups_outlined;
    final bgColor = (g['bgColor'] as Color?) ?? const Color(0xFFF3EBFF);
    final iconColor = (g['iconColor'] as Color?) ?? const Color(0xFF7C3AED);

    return InkWell(
      onTap: () => _openGroupDetails(g),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
          boxShadow: const [studioShadow],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: campaignText(12, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_alt_outlined, size: 12, color: muted),
                const SizedBox(width: 3),
                Text(
                  fmt.format(count),
                  style: campaignText(11, color: muted, weight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addGroupCard() {
    return InkWell(
      onTap: _openCreateGroup,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderBlue),
          boxShadow: const [studioShadow],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFEDF2F7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: teal, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'Add Group',
              style: campaignText(12, weight: FontWeight.w700, color: teal),
            ),
            const SizedBox(height: 2),
            Text(
              'Create new',
              style: campaignText(10.5, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = key),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? teal : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? teal : borderBlue.withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            label,
            style: campaignText(
              12,
              color: isSelected ? Colors.white : ink,
              weight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerTile(Map<String, dynamic> c) {
    final name = c['name'] ?? 'Customer';
    final phone = c['phone'] ?? '';
    final tag = c['tag'] ?? 'Member';
    final totalSpend = c['totalSpend'] ?? 0;
    final lastVisit = c['lastVisit'] ?? '21 Nov 2026';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Initial avatar colors
    final initials = name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
    final (avatarBg, avatarFg) = _avatarColors(tag);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: campaignCard(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarBg,
            child: Text(
              initials.isNotEmpty ? initials : 'C',
              style: campaignText(13, weight: FontWeight.w700, color: avatarFg),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: campaignText(14.5, weight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _tagBadge(tag),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: borderBlue),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 13, color: muted),
                    const SizedBox(width: 4),
                    Text(phone, style: campaignText(12, color: muted)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 12, color: muted),
                    const SizedBox(width: 3),
                    Text(
                      'Total Spend: ${fmt.format(totalSpend)}',
                      style: campaignText(11.5, weight: FontWeight.w600),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Text('|', style: TextStyle(color: borderBlue, fontSize: 11)),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 11, color: muted),
                    const SizedBox(width: 3),
                    Text(
                      'Last Visit: $lastVisit',
                      style: campaignText(11, color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _avatarColors(String tag) {
    switch (tag.toLowerCase()) {
      case 'vip':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'new':
        return (const Color(0xFFE0F2FE), const Color(0xFF0369A1));
      case 'inactive':
        return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
      default:
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
    }
  }

  Widget _tagBadge(String tag) {
    Color bg;
    Color fg;
    IconData icon;

    switch (tag.toLowerCase()) {
      case 'vip':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        icon = Icons.workspace_premium_outlined;
        break;
      case 'new':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        icon = Icons.auto_awesome_rounded;
        break;
      case 'inactive':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        icon = Icons.block_flipped;
        break;
      default:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.people_alt_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(tag, style: campaignText(11, color: fg, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _fullGroupTile(Map<String, dynamic> g) {
    final name = g['name'] ?? 'Group';
    final count = g['count'] ?? 0;
    final fmt = NumberFormat.decimalPattern('en_IN');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: campaignCard(radius: 14),
      child: InkWell(
        onTap: () => _openGroupDetails(g),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_outlined, color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: campaignText(15, weight: FontWeight.w700)),
                  Text(
                    '${fmt.format(count)} Members',
                    style: campaignText(12, color: muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: borderBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 7, 13, 5),
      color: Colors.white.withValues(alpha: 0.9),
      child: Container(
        decoration: campaignCard(
          radius: 15,
          color: const Color(0xFFF5FAFE),
        ),
        child: Row(
          children: [
            _navItem(
              'Home',
              Icons.home_outlined,
              widget.onBack ?? () => Navigator.maybePop(context),
            ),
            _navItem(
              'Campaigns',
              Icons.campaign_outlined,
              widget.onNavigateToCampaigns ?? () => Navigator.maybePop(context),
            ),
            _navItem(
              'Customers',
              Icons.people_alt_rounded,
              () {},
              selected: true,
            ),
            _navItem(
              'Reports',
              Icons.bar_chart_rounded,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports')),
                );
              },
            ),
            _navItem(
              'More',
              Icons.more_horiz,
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    String label,
    IconData icon,
    VoidCallback tap, {
    bool selected = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? teal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: selected ? Colors.white : ink),
              Text(
                label,
                style: campaignText(11, color: selected ? Colors.white : ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
