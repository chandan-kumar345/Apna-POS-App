import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/widgets/pos_screen_top_header.dart';
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
  final bool showHeader;
  const MobileCustomersScreen({
    super.key,
    this.options,
    this.onBack,
    this.onNavigateToCampaigns,
    this.api,
    this.showHeader = false,
  });
  @override
  State<MobileCustomersScreen> createState() => _MobileCustomersScreenState();
}

class _MobileCustomersScreenState extends State<MobileCustomersScreen> {
  late final MobileCustomersApi _api = widget.api ?? MobileCustomersApi();
  final _search = TextEditingController();
  final _format = NumberFormat.decimalPattern('en_IN');
  Timer? _debounce;
  int _tab = 1, _request = 0, _page = 1, _matches = 0;
  int? _totalCustomers;
  List<CustomerModel> _customers = [];
  List<AudienceGroupModel>? _groups;
  bool _loadingCustomers = false, _loadingGroups = false;
  String? _customerError, _groupError;
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
    _loadCustomers();
  }

  void _searchChanged(String value) {
    setState(() {});
    if (_tab == 0) {
      // Invalidate the previous response immediately, before the debounce ends.
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
            ...group.toJson(),
            'count': group.totalNumbers,
            'createdAt': group.createdAt?.toIso8601String(),
            'updatedAt': group.updatedAt?.toIso8601String(),
          },
        ),
      ),
    );
    if (mounted) await _loadGroups();
  }

  Future<void> _deleteGroup(AudienceGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          'Delete "${group.name}"? Your customer profiles will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteGroup(group.id);
      if (mounted) {
        _message('Group deleted');
        await _loadGroups();
      }
    } catch (_) {
      if (mounted) _message('Could not delete the group. Please retry.');
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
            title: const Text('Add customer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.words,
                    decoration: customerInput('Customer name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phone,
                    enabled: !saving,
                    keyboardType: TextInputType.phone,
                    decoration: customerInput(
                      'Mobile number with country code',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final normalized = normalizeCustomerPhone(phone.text);
                        if (name.text.trim().isEmpty || normalized == null) {
                          update(
                            () => error =
                                'Enter a name and a valid number with country code.',
                          );
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await _api.saveCustomer(name.text, normalized);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            update(() {
                              saving = false;
                              error =
                                  'Could not save the customer. Please retry.';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Add customer'),
              ),
            ],
          ),
        ),
      ),
    );
    // Dialog route animations may still use the controllers after it returns.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    phone.dispose();
    if (mounted && result == true) {
      _search.clear();
      await _loadCustomers();
      _message('Customer saved');
    }
  }

  void _more() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh customers and groups'),
            onTap: () {
              Navigator.pop(sheetContext);
              _refresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Add customer'),
            onTap: () {
              Navigator.pop(sheetContext);
              _switchTab(0);
              _addCustomer();
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Go to campaigns'),
            onTap: () {
              Navigator.pop(sheetContext);
              (widget.onNavigateToCampaigns ??
                  () => Navigator.maybePop(context))();
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final groups = (_groups ?? [])
        .where((group) => group.name.toLowerCase().contains(query))
        .toList();
    final loading = _tab == 1 ? _loadingGroups : _loadingCustomers;
    final error = _tab == 1 ? _groupError : _customerError;
    final count = _tab == 1 ? groups.length : _matches;

    final bodyWidget = RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF0077B6),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        children: [
          const SizedBox(height: 6),

          // Header Row: Title & Subtitle on left, 3D Customer Group Graphic on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.onBack != null) ...[
                          IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFF0F1E36),
                            ),
                            tooltip: 'Back',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Text(
                          'Customers',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F1E36),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage customers and their groups.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const _CustomerGroup3DGraphic(),
            ],
          ),
          const SizedBox(height: 14),

          // Metric Cards: Total customers & Groups
          Row(
            children: [
              _metricCard(
                label: 'Total customers',
                value: _totalCustomers == null
                    ? '—'
                    : _format.format(_totalCustomers),
                icon: Icons.people_alt_rounded,
                gradient: const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
                iconColor: const Color(0xFF8B5CF6),
                waveColor: const Color(0xFFEDE9FE),
                onTap: () => _switchTab(0),
              ),
              const SizedBox(width: 12),
              _metricCard(
                label: 'Groups',
                value: '${_groups?.length ?? 0}',
                icon: Icons.folder_rounded,
                gradient: const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
                iconColor: const Color(0xFF10B981),
                waveColor: const Color(0xFFDCFCE7),
                onTap: () => _switchTab(1),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Input Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE2EDF5).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFD6E4EF),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _search,
              onChanged: _searchChanged,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Color(0xFF0F1E36),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: _tab == 1 ? 'Search groups...' : 'Search customers...',
                hintStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () {
                          _search.clear();
                          _searchChanged('');
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tab Toggle: All customers / Groups
          Row(
            children: [
              _tabPill(
                index: 0,
                label: 'All customers',
                activeIcon: Icons.person_rounded,
                inactiveIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(width: 10),
              _tabPill(
                index: 1,
                label: 'Groups',
                activeIcon: Icons.people_alt_rounded,
                inactiveIcon: Icons.people_alt_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section Header: Title & Count Badge
          Row(
            children: [
              Text(
                _tab == 1 ? 'Your groups' : 'Your customers',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F1E36),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count ${_tab == 1 ? (count == 1 ? 'group' : 'groups') : (count == 1 ? 'customer' : 'customers')}',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                color: Color(0xFF0077B6),
                backgroundColor: Color(0xFFE0F2FE),
              ),
            ),

          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    error,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: muted,
                    ),
                  ),
                  TextButton(
                    onPressed: _tab == 1 ? _loadGroups : _loadCustomers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          if (!loading && error == null && count == 0) _empty(query),

          if (!loading || count > 0)
            ...(_tab == 1
                ? [
                    for (var i = 0; i < groups.length; i++)
                      _groupCard(groups[i], i),
                  ]
                : [
                    for (final customer in _customers)
                      _customerCard(customer),
                  ]),

          if (_tab == 0 && _customers.length < _matches)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: TextButton(
                  onPressed: _loadingCustomers
                      ? null
                      : () => _loadCustomers(more: true),
                  child: const Text('Load more customers'),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );

    final footerWidget = Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bottom Floating "+ Create group" / "+ Add customer" Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: _tab == 1 ? () => _editGroup() : _addCustomer,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _tab == 1 ? 'Create group' : 'Add customer',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Navigation Bar (Unified with Campaigns screen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _navItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  onTap: widget.onBack ?? () => Navigator.maybePop(context),
                ),
                _navItem(
                  label: 'Campaigns',
                  icon: Icons.campaign_outlined,
                  onTap: widget.onNavigateToCampaigns ??
                      () => Navigator.maybePop(context),
                ),
                _navItem(
                  label: 'Customers',
                  icon: Icons.people_alt_rounded,
                  selected: true,
                  onTap: () {
                    _search.clear();
                    _switchTab(0);
                  },
                ),
                _navItem(
                  label: 'More',
                  icon: Icons.more_horiz_rounded,
                  onTap: _more,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.showHeader) {
      return ColoredBox(
        color: const Color(0xFFEDF4FA),
        child: CustomerShell(
          header: const PosScreenTopHeader(),
          body: bodyWidget,
          footer: footerWidget,
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFFEDF4FA),
      child: CampaignShell(
        body: bodyWidget,
        footer: footerWidget,
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    required Color iconColor,
    required Color waveColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -16,
                  bottom: -20,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: waveColor.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F1E36),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabPill({
    required int index,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final selected = _tab == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _switchTab(index),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                    )
                  : null,
              color: selected ? null : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? const Color(0xFF0077B6).withValues(alpha: 0.35)
                      : const Color(0xFF0B2545).withValues(alpha: 0.05),
                  blurRadius: selected ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? activeIcon : inactiveIcon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF475569),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF0F1E36),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0077B6).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : const Color(0xFF475569),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupCard(AudienceGroupModel group, int index) {
    final count = group.totalNumbers;
    final isVip = group.name.toLowerCase().contains('vip');

    // 3D icon styling for group
    final (icon, gradient, iconColor, shadowColor) = isVip
        ? (
            Icons.workspace_premium_rounded,
            const [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
            const Color(0xFFD97706),
            const Color(0xFFD97706).withValues(alpha: 0.25),
          )
        : (
            Icons.folder_rounded,
            const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
            const Color(0xFF0284C7),
            const Color(0xFF0284C7).withValues(alpha: 0.22),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          onTap: () => _openGroup(group),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3D Icon Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name, Tag, Chevron
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F1E36),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isVip
                                  ? const Color(0xFFFFEDD5)
                                  : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isVip ? 'VIP' : 'Group',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isVip
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Row 2: Metadata (Numbers | Updated)
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_format.format(count)} ${count == 1 ? 'number' : 'numbers'}',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F1E36),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7),
                            child: Text(
                              '|',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _updated(group),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Row 3: Ready for campaigns pill & options button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me_rounded,
                                  size: 13,
                                  color: Color(0xFF0284C7),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Ready for campaigns',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: PopupMenuButton<String>(
                              tooltip: 'Options for ${group.name}',
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editGroup(group);
                                } else {
                                  _deleteGroup(group);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit group'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete group'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerCard(CustomerModel customer) {
    final isVip = customer.totalOrders >= 5;
    final isMember = customer.totalOrders > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3D Avatar Icon Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF0284C7),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),

                // Customer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F1E36),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isVip
                                  ? const Color(0xFFFFEDD5)
                                  : (isMember
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFE0F2FE)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isVip ? 'VIP' : (isMember ? 'Member' : 'New'),
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isVip
                                    ? const Color(0xFFEA580C)
                                    : (isMember
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF0284C7)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Phone Number
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Stats Row
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${customer.totalOrders} ${customer.totalOrders == 1 ? 'order' : 'orders'}',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F1E36),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7),
                            child: Text(
                              '|',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isMember ? 'Active Buyer' : 'Customer Profile',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _updated(AudienceGroupModel group) {
    final date = group.updatedAt ?? group.createdAt;
    if (date == null) return 'Update date unavailable';
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
      (Icons.campaign_outlined, const Color(0xFF7049AE), const Color(0xFFE2D8FA)),
      (
        Icons.workspace_premium_outlined,
        const Color(0xFFAA6900),
        const Color(0xFFFFE2A0),
      ),
      (Icons.cake_outlined, const Color(0xFFB8490C), const Color(0xFFFFD8C7)),
      (
        Icons.schedule_outlined,
        const Color(0xFFB72F1B),
        const Color(0xFFFFCCD3),
      ),
      (
        Icons.person_add_alt_outlined,
        const Color(0xFF09851E),
        const Color(0xFFBCF8D0),
      ),
      (
        Icons.star_outline_rounded,
        const Color(0xFF0583FA),
        const Color(0xFFB1E6FF),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 35),
        child: Column(
          children: [
            Icon(
              _tab == 1 ? Icons.folder_open_outlined : Icons.people_outline,
              size: 40,
              color: muted,
            ),
            const SizedBox(height: 10),
            Text(
              query.isNotEmpty
                  ? 'No matching ${_tab == 1 ? 'groups' : 'customers'}'
                  : _tab == 1
                      ? 'Create your first customer group'
                      : 'Your customers will appear here',
              textAlign: TextAlign.center,
              style: campaignText(15, weight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              query.isNotEmpty
                  ? 'Try a different search.'
                  : _tab == 1
                      ? 'Add numbers manually or import a spreadsheet.'
                      : 'Add a customer to get started.',
              textAlign: TextAlign.center,
              style: campaignText(12, color: muted, weight: FontWeight.w400),
            ),
          ],
        ),
      );
}

/// 3D Customer Group Graphic with avatars and golden plus badge matching design mockup
class _CustomerGroup3DGraphic extends StatelessWidget {
  const _CustomerGroup3DGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft radial glow background
          Container(
            width: 82,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE0F7FA).withValues(alpha: 0.9),
                  const Color(0xFFE0F2FE).withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // Custom 3D Avatar Figures
          Positioned.fill(
            child: CustomPaint(
              painter: _CustomerGroup3DPainter(),
            ),
          ),

          // Golden Plus Badge at bottom right
          Positioned(
            right: 4,
            bottom: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerGroup3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.46;
    final cy = size.height * 0.52;

    // 1. Back Left Avatar
    final backLeftHeadCenter = Offset(cx - 16, cy - 8);
    final backLeftHeadPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.8,
        colors: const [Color(0xFF26C6DA), Color(0xFF007791)],
      ).createShader(Rect.fromCircle(center: backLeftHeadCenter, radius: 6.5));
    canvas.drawCircle(backLeftHeadCenter, 6.5, backLeftHeadPaint);

    final backLeftBodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00ACC1), Color(0xFF006064)],
      ).createShader(Rect.fromLTWH(cx - 24, cy - 1, 16, 18));
    final backLeftBodyPath = Path();
    backLeftBodyPath.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - 24, cy - 1, 16, 18),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
    );
    canvas.drawPath(backLeftBodyPath, backLeftBodyPaint);

    // 2. Back Right Avatar
    final backRightHeadCenter = Offset(cx + 16, cy - 8);
    final backRightHeadPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.8,
        colors: const [Color(0xFF26C6DA), Color(0xFF007791)],
      ).createShader(Rect.fromCircle(center: backRightHeadCenter, radius: 6.5));
    canvas.drawCircle(backRightHeadCenter, 6.5, backRightHeadPaint);

    final backRightBodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00ACC1), Color(0xFF006064)],
      ).createShader(Rect.fromLTWH(cx + 8, cy - 1, 16, 18));
    final backRightBodyPath = Path();
    backRightBodyPath.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx + 8, cy - 1, 16, 18),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
    );
    canvas.drawPath(backRightBodyPath, backRightBodyPaint);

    // 3. Center Front Avatar Body
    final frontBodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00BCD4), Color(0xFF00838F)],
      ).createShader(Rect.fromLTWH(cx - 14, cy + 3, 28, 24));

    final frontBodyPath = Path();
    frontBodyPath.moveTo(cx - 13, cy + 24);
    frontBodyPath.quadraticBezierTo(cx - 12, cy + 5, cx, cy + 4);
    frontBodyPath.quadraticBezierTo(cx + 12, cy + 5, cx + 13, cy + 24);
    frontBodyPath.close();
    canvas.drawPath(frontBodyPath, frontBodyPaint);

    // Highlight on front body
    final frontBodyHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(cx - 10, cy + 5, 20, 10));
    final highlightPath = Path();
    highlightPath.moveTo(cx - 10, cy + 12);
    highlightPath.quadraticBezierTo(cx - 8, cy + 5, cx, cy + 5);
    highlightPath.quadraticBezierTo(cx + 8, cy + 5, cx + 10, cy + 12);
    canvas.drawPath(highlightPath, frontBodyHighlight);

    // 4. Center Front Avatar Head
    final frontHeadCenter = Offset(cx, cy - 5);
    final frontHeadPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.85,
        colors: const [
          Color(0xFF80DEEA),
          Color(0xFF26C6DA),
          Color(0xFF00838F),
        ],
      ).createShader(Rect.fromCircle(center: frontHeadCenter, radius: 8.5));

    // Drop shadow under head
    canvas.drawCircle(
      frontHeadCenter.translate(0, 1.5),
      8.5,
      Paint()
        ..color = const Color(0xFF004D40).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(frontHeadCenter, 8.5, frontHeadPaint);

    // Specular highlight on front head
    canvas.drawCircle(
      frontHeadCenter.translate(-2.5, -2.5),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
