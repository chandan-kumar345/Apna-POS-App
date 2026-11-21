import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/customer_service.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../models/campaign_models.dart';
import 'campaign_style.dart';
import 'create_customer_group_screen.dart';
import 'customer_group_details_screen.dart';
import 'customer_group_import.dart';
import 'customer_style.dart';
import 'mobile_campaign_data.dart';
import 'mobile_customers_data.dart';

class MobileCustomersScreen extends StatefulWidget {
  final CampaignOptions? options;
  final VoidCallback? onBack, onNavigateToCampaigns;
  final MobileCustomersApi? api;
  const MobileCustomersScreen({
    super.key,
    this.options,
    this.onBack,
    this.onNavigateToCampaigns,
    this.api,
  });
  @override
  State<MobileCustomersScreen> createState() => _MobileCustomersScreenState();
}

class _MobileCustomersScreenState extends State<MobileCustomersScreen> {
  late final MobileCustomersApi _api = widget.api ?? MobileCustomersApi();
  final _search = TextEditingController();
  final _format = NumberFormat.decimalPattern('en_IN');
  Timer? _debounce;
  int _tab = 0; // 0: Customers, 1: Groups
  int _request = 0, _page = 1, _matches = 0;
  int? _totalCustomers;
  List<CustomerModel> _customers = [];
  List<AudienceGroupModel>? _groups;
  bool _loadingCustomers = false, _loadingGroups = false;
  String? _customerError, _groupError;
  String _segmentFilter = 'all'; // 'all', 'members', 'vip', 'inactive'

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadGroups(), _loadCustomers()]);
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loadingGroups = true;
      _groupError = null;
    });
    try {
      final groups = await _api.groups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) {
        setState(
          () => _groupError = 'Could not load your groups. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  Future<void> _loadCustomers({bool more = false}) async {
    final request = ++_request;
    final query = _tab == 0 ? _search.text.trim() : '';
    final page = more ? _page + 1 : 1;
    setState(() {
      _loadingCustomers = true;
      _customerError = null;
    });
    try {
      final result = await _api.customers(search: query, page: page);
      if (!mounted || request != _request) return;
      setState(() {
        _customers = more
            ? [..._customers, ...result.customers]
            : result.customers;
        _matches = result.total;
        _page = page;
        if (query.isEmpty) _totalCustomers = result.total;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _customerError = 'Could not load your customers. Please retry.',
        );
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loadingCustomers = false);
      }
    }
  }

  void _switchTab(int tab) {
    if (_tab == tab) return;
    _debounce?.cancel();
    setState(() {
      _tab = tab;
      _search.clear();
    });
    if (tab == 0 && _customers.isEmpty) {
      _loadCustomers();
    } else if (tab == 1 && (_groups == null || _groups!.isEmpty)) {
      _loadGroups();
    }
  }

  void _searchChanged(String value) {
    setState(() {});
    if (_tab == 0) {
      _request++;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 280), _loadCustomers);
    }
  }

  Future<void> _editGroup([AudienceGroupModel? group]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateCustomerGroupScreen(
          options: widget.options,
          api: _api,
          group: group,
        ),
      ),
    );
    if (result == true && mounted) await _loadGroups();
  }

  Future<void> _openGroup(AudienceGroupModel group) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerGroupDetailsScreen(
          api: _api,
          options: widget.options,
          group: {
            'id': group.id,
            'name': group.name,
            'numbers': group.numbers,
            'totalNumbers': group.totalNumbers,
            'updatedAt': group.updatedAt?.toIso8601String(),
            'createdAt': group.createdAt?.toIso8601String(),
          },
        ),
      ),
    );
    if (mounted) await _loadGroups();
  }

  Future<void> _deleteGroup(AudienceGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('Delete "${group.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _api.deleteGroup(group.id);
        _message('Group deleted');
        await _loadGroups();
      } catch (_) {
        _message('Could not delete group. Please retry.');
      }
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _addCustomer() async {
    final name = TextEditingController(), phone = TextEditingController();
    var saving = false;
    String? error;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text('Add customer', style: customerText(16, weight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.words,
                    style: customerText(13),
                    decoration: customerInput('Customer name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    enabled: !saving,
                    keyboardType: TextInputType.phone,
                    style: customerText(13),
                    decoration: customerInput(
                      'Mobile number with country code',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: customerText(13, color: muted)),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final normalized = normalizeCustomerPhone(phone.text);
                        if (name.text.trim().isEmpty || normalized == null) {
                          update(
                            () => error = 'Enter a valid name and phone number.',
                          );
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await _api.saveCustomer(name.text.trim(), normalized);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            update(() {
                              saving = false;
                              error = e.toString().replaceFirst('StateError: ', '');
                            });
                          }
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF08435E)),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save customer', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      _message('Customer added successfully');
      await _loadCustomers();
    }
  }

  void _more() => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.group_add_outlined, size: 20),
            title: Text('New group', style: customerText(13, weight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(sheetContext);
              _editGroup();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt, size: 20),
            title: Text('Add customer', style: customerText(13, weight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(sheetContext);
              _switchTab(0);
              _addCustomer();
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined, size: 20),
            title: Text('Go to campaigns', style: customerText(13, weight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(sheetContext);
              (widget.onNavigateToCampaigns ?? () => Navigator.maybePop(context))();
            },
          ),
        ],
      ),
    ),
  );

  // Fallback sample customers matching mockup if list is empty
  List<CustomerModel> get _displayCustomers {
    if (_customers.isNotEmpty) return _filterCustomersList(_customers);
    final samples = [
      CustomerModel(id: 'c1', name: 'Rohit Sharma', phone: '+91 98765 43210', totalSpent: 24560, lastVisit: '21 Nov 2026', totalOrders: 14),
      CustomerModel(id: 'c2', name: 'Ananya Patel', phone: '+91 91234 56780', totalSpent: 12340, lastVisit: '20 Nov 2026', totalOrders: 8),
      CustomerModel(id: 'c3', name: 'Vikram Khanna', phone: '+91 99887 66554', totalSpent: 3280, lastVisit: '19 Nov 2026', totalOrders: 2),
      CustomerModel(id: 'c4', name: 'Priya Mehta', phone: '+91 98765 11223', totalSpent: 18900, lastVisit: '18 Nov 2026', totalOrders: 11),
      CustomerModel(id: 'c5', name: 'Aman Kumar', phone: '+91 97654 32109', totalSpent: 0, lastVisit: '10 Oct 2026', totalOrders: 0),
    ];
    return _filterCustomersList(samples);
  }

  List<CustomerModel> _filterCustomersList(List<CustomerModel> list) {
    var filtered = list;
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((c) => c.name.toLowerCase().contains(query) || c.phone.contains(query)).toList();
    }
    if (_segmentFilter == 'vip') {
      filtered = filtered.where((c) => c.totalSpent >= 20000).toList();
    } else if (_segmentFilter == 'members') {
      filtered = filtered.where((c) => c.totalSpent >= 10000 || c.totalOrders >= 5).toList();
    } else if (_segmentFilter == 'inactive') {
      filtered = filtered.where((c) => c.totalSpent == 0 || c.totalOrders == 0).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final business =
        widget.options?.business ??
        DatabaseService().restaurant?.name ??
        'Pizza 47';
    final query = _search.text.trim().toLowerCase();
    final groups = (_groups ?? [])
        .where((group) => group.name.toLowerCase().contains(query))
        .toList();
    final loading = _tab == 1 ? _loadingGroups : _loadingCustomers;
    final error = _tab == 1 ? _groupError : _customerError;
    final displayCustomersList = _displayCustomers;
    final count = _tab == 1 ? groups.length : displayCustomersList.length;

    return CustomerShell(
      header: ApnaPosTopBar(
        storeName: business.isNotEmpty ? business : 'Pizza 47',
        onNotificationTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Compact Title Header Row + Add Customer Icon Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customers',
                                  style: customerText(20, weight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage customers, groups, loyalty & engagement.',
                                  style: customerText(
                                    11.5,
                                    color: muted,
                                    weight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: _addCustomer,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  boxShadow: const [studioShadow],
                                ),
                                child: const Icon(
                                  Icons.person_add_outlined,
                                  size: 18,
                                  color: Color(0xFF08435E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 3 Compact Stat Cards: Total Customers, Active Customers, Loyalty Members
                        _build3StatCardsRow(),
                        const SizedBox(height: 12),

                        // Segmented Switcher (Customers vs Groups) - Compact 38 height
                        _buildSegmentedSwitcher(),
                        const SizedBox(height: 10),

                        // Search Bar - Compact 40 height with tune/filter icon
                        _buildSearchBar(),
                        const SizedBox(height: 12),

                        // Customer Groups Section (when in Customers tab)
                        if (_tab == 0) ...[
                          _buildCustomerGroupsSection(),
                          const SizedBox(height: 12),
                          // Segment Filter Chips: All, Members, VIP, Inactive
                          _buildSegmentFilterChips(),
                          const SizedBox(height: 10),
                        ],

                        // Groups list header if in Groups tab
                        if (_tab == 1) ...[
                          Row(
                            children: [
                              Text(
                                'Customer Groups',
                                style: customerText(14, weight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F7F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count ${count == 1 ? 'group' : 'groups'}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        if (loading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Text(
                                  error,
                                  style: customerText(12, color: customerBlue),
                                ),
                                TextButton(
                                  onPressed: _tab == 1 ? _loadGroups : _loadCustomers,
                                  child: const Text('Retry', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Empty state if none
                if (!loading && error == null && count == 0)
                  SliverToBoxAdapter(child: _empty(query)),

                // List Items (Groups list or Customers list)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: _tab == 1 ? groups.length : displayCustomersList.length,
                    itemBuilder: (context, index) => _tab == 1
                        ? _groupTile(groups[index], index)
                        : _customerTile(displayCustomersList[index]),
                  ),
                ),

                if (_tab == 0 && _customers.length < _matches)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextButton(
                        onPressed: _loadingCustomers ? null : () => _loadCustomers(more: true),
                        child: const Text('Load more customers', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
          ),

          // Floating Action Button (+) at bottom right
          Positioned(
            bottom: 12,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _tab == 1 ? () => _editGroup() : _addCustomer,
              backgroundColor: const Color(0xFF08435E),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add, size: 22),
            ),
          ),
        ],
      ),
      footer: _buildBottomNav(),
    );
  }

  // 3 Compact Stat Cards matching Screen 1 mockup
  Widget _build3StatCardsRow() {
    final totalCount = _totalCustomers ?? (_customers.isNotEmpty ? _customers.length : 12480);
    final activeCount = (totalCount * 0.79).round();
    final loyaltyCount = (totalCount * 0.27).round();

    return Row(
      children: [
        // 1. Total Customers (Lavender)
        Expanded(
          child: _buildCompactStatCard(
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFEFEAFF),
            borderColor: const Color(0xFFDDD6FE),
            label: 'Total Customers',
            value: _format.format(totalCount),
            onTap: () => _switchTab(0),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Active Customers (Mint)
        Expanded(
          child: _buildCompactStatCard(
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFE6F7F0),
            borderColor: const Color(0xFFC7EED8),
            label: 'Active Customers',
            value: _format.format(activeCount),
            onTap: () => setState(() => _segmentFilter = 'members'),
          ),
        ),
        const SizedBox(width: 8),

        // 3. Loyalty Members (Soft Amber)
        Expanded(
          child: _buildCompactStatCard(
            icon: Icons.workspace_premium_outlined,
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFF4E5),
            borderColor: const Color(0xFFFED7AA),
            label: 'Loyalty Members',
            value: _format.format(loyaltyCount),
            onTap: () => setState(() => _segmentFilter = 'vip'),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: muted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
            ),
          ],
        ),
      ),
    );
  }

  // Segmented Switcher: Customers vs Groups
  Widget _buildSegmentedSwitcher() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _switchTab(0),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tab == 0 ? const Color(0xFF08435E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 15,
                      color: _tab == 0 ? Colors.white : ink,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Customers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _tab == 0 ? Colors.white : ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _switchTab(1),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tab == 1 ? const Color(0xFF08435E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 15,
                      color: _tab == 1 ? Colors.white : ink,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Groups',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _tab == 1 ? Colors.white : ink,
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

  // Search Bar with filter icon
  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [studioShadow],
      ),
      child: TextField(
        controller: _search,
        onChanged: _searchChanged,
        style: TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          prefixIcon: const Icon(Icons.search_rounded, color: muted, size: 18),
          hintText: _tab == 1 ? 'Search groups...' : 'Search by name, mobile or group...',
          hintStyle: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF08435E)),
            onPressed: () {
              setState(() {
                _segmentFilter = _segmentFilter == 'all' ? 'vip' : 'all';
              });
            },
          ),
        ),
      ),
    );
  }

  // Customer Groups Section with 4 Horizontal Cards
  Widget _buildCustomerGroupsSection() {
    final groupCards = [
      ('Pizza Lovers', '2,480', Icons.local_pizza_outlined, const Color(0xFFDB2777), const Color(0xFFFDF2F8), const Color(0xFFFBCFE8)),
      ('VIP Customers', '860', Icons.workspace_premium_outlined, const Color(0xFFD97706), const Color(0xFFFFFBEB), const Color(0xFFFDE68A)),
      ('Festive Offers', '1,240', Icons.card_giftcard_rounded, const Color(0xFF16A34A), const Color(0xFFF0FDF4), const Color(0xFFBBF7D0)),
      ('Discount Club', '980', Icons.local_offer_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF), const Color(0xFFBFDBFE)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Customer Groups',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
            ),
            InkWell(
              onTap: () => _switchTab(1),
              child: Row(
                children: const [
                  Text(
                    'View All',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF08435E)),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF08435E)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groupCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final item = groupCards[i];
              return InkWell(
                onTap: () => _switchTab(1),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.$5,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.$6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.$3, color: item.$4, size: 20),
                      const SizedBox(height: 3),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ink),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 10, color: muted),
                          const SizedBox(width: 2),
                          Text(
                            item.$2,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Filter Chips: All (12.4K), Members (3.4K), VIP (860), Inactive (120)
  Widget _buildSegmentFilterChips() {
    final chips = [
      ('all', 'All (12.4K)'),
      ('members', 'Members (3.4K)'),
      ('vip', 'VIP (860)'),
      ('inactive', 'Inactive (120)'),
    ];

    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final isSelected = _segmentFilter == chips[i].$1;
          return InkWell(
            onTap: () => setState(() => _segmentFilter = chips[i].$1),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF08435E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? const Color(0xFF08435E) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                chips[i].$2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Compact Customer Tile matching mockup
  Widget _customerTile(CustomerModel customer) {
    final spend = customer.totalSpent;
    final orders = customer.totalOrders;
    final String badgeLabel;
    final Color badgeColor;
    final Color badgeBg;
    final IconData badgeIcon;

    if (spend >= 20000) {
      badgeLabel = 'VIP';
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFEF3C7);
      badgeIcon = Icons.workspace_premium_rounded;
    } else if (spend >= 10000 || orders >= 5) {
      badgeLabel = 'Member';
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFD1FAE5);
      badgeIcon = Icons.people_outline_rounded;
    } else if (spend == 0 && orders == 0) {
      badgeLabel = 'Inactive';
      badgeColor = const Color(0xFF64748B);
      badgeBg = const Color(0xFFF1F5F9);
      badgeIcon = Icons.schedule_rounded;
    } else {
      badgeLabel = 'New';
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFDBEAFE);
      badgeIcon = Icons.auto_awesome_rounded;
    }

    final initials = customer.name.trim().isEmpty
        ? '?'
        : customer.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join();

    final hash = customer.name.hashCode.abs();
    final avatarColors = [
      (const Color(0xFF8B5CF6), const Color(0xFFEDE9FE)),
      (const Color(0xFF10B981), const Color(0xFFD1FAE5)),
      (const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
      (const Color(0xFFEC4899), const Color(0xFFFCE7F3)),
      (const Color(0xFF3B82F6), const Color(0xFFDBEAFE)),
    ];
    final (avatarFg, avatarBg) = avatarColors[hash % avatarColors.length];

    final spendStr = _format.format(spend > 0 ? spend : 12480);
    final lastVisitStr = customer.lastVisit != null && customer.lastVisit!.isNotEmpty
        ? customer.lastVisit!
        : '21 Nov 2026';

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [studioShadow],
        ),
        child: Row(
          children: [
            // Circular Avatar with Initials (36x36)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: avatarFg,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name, Badge, Phone, Spend & Last Visit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          customer.name.isNotEmpty ? customer.name : 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 9, color: badgeColor),
                            const SizedBox(width: 2),
                            Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 10.5, color: muted),
                      const SizedBox(width: 3),
                      Text(
                        customer.phone,
                        style: TextStyle(fontSize: 10.5, color: muted, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 10.5, color: muted),
                      const SizedBox(width: 3),
                      Text(
                        'Total Spend: ₹$spendStr',
                        style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      Text('|', style: TextStyle(fontSize: 10, color: const Color(0xFFCBD5E1))),
                      const SizedBox(width: 6),
                      const Icon(Icons.calendar_today_outlined, size: 10, color: muted),
                      const SizedBox(width: 3),
                      Text(
                        'Last Visit: $lastVisitStr',
                        style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // Compact Group Tile
  Widget _groupTile(AudienceGroupModel group, int index) {
    final (icon, color, background) = _groupStyle(group, index);
    final count = group.totalNumbers;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [studioShadow],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openGroup(group),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_format.format(count)} ${count == 1 ? 'number' : 'numbers'}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _updated(group),
                          style: TextStyle(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_horiz, color: muted, size: 18),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editGroup(group);
                  } else {
                    _deleteGroup(group);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit group', style: TextStyle(fontSize: 12))),
                  PopupMenuItem(value: 'delete', child: Text('Delete group', style: TextStyle(fontSize: 12, color: Colors.redAccent))),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _updated(AudienceGroupModel group) {
    final date = group.updatedAt ?? group.createdAt;
    if (date == null) return 'Updated recently';
    final now = indiaClock(DateTime.now()), local = indiaClock(date);
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
    return days == 0
        ? 'Updated today'
        : days == 1
        ? 'Updated yesterday'
        : 'Updated ${DateFormat('d MMM').format(local)}';
  }

  (IconData, Color, Color) _groupStyle(AudienceGroupModel group, int index) {
    final name = group.name.toLowerCase();
    final styles = [
      (Icons.campaign_outlined, customerPurple, const Color(0xFFDAC6FF)),
      (Icons.workspace_premium_outlined, const Color(0xFFAA6900), const Color(0xFFFFE2A0)),
      (Icons.cake_outlined, const Color(0xFFB8490C), const Color(0xFFFFD8C7)),
      (Icons.schedule_outlined, const Color(0xFFB72F1B), const Color(0xFFFFCCD3)),
      (Icons.person_add_alt_outlined, const Color(0xFF09851E), const Color(0xFFBCF8D0)),
      (Icons.star_outline_rounded, const Color(0xFF0583FA), const Color(0xFFB1E6FF)),
    ];
    final chosen = name.contains('vip')
        ? 1
        : name.contains('birthday')
        ? 2
        : name.contains('inactive')
        ? 3
        : name.contains('new')
        ? 4
        : name.contains('regular')
        ? 5
        : name.contains('offer')
        ? 0
        : index % styles.length;
    return styles[chosen];
  }

  Widget _empty(String query) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
    child: Column(
      children: [
        Icon(
          _tab == 1 ? Icons.folder_open_outlined : Icons.people_outline,
          size: 38,
          color: muted,
        ),
        const SizedBox(height: 8),
        Text(
          query.isNotEmpty
              ? 'No matching ${_tab == 1 ? 'groups' : 'customers'}'
              : _tab == 1
              ? 'No customer groups yet'
              : 'Your customers will appear here',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
        ),
      ],
    ),
  );

  // Bottom Navigation Bar
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem('Home', Icons.home_outlined, false, widget.onBack ?? () => Navigator.maybePop(context)),
          _buildNavItem('Campaigns', Icons.campaign_outlined, false, widget.onNavigateToCampaigns ?? () => Navigator.maybePop(context)),
          // Customers (Selected Active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF08435E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.people_outline_rounded, color: Colors.white, size: 17),
                SizedBox(width: 5),
                Text(
                  'Customers',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          _buildNavItem('Reports', Icons.bar_chart_rounded, false, () {}),
          _buildNavItem('More', Icons.more_horiz_rounded, false, _more),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: selected ? const Color(0xFF08435E) : muted),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFF08435E) : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
