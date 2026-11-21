import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/widgets/pos_screen_top_header.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../models/campaign_models.dart';
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
    final business =
        widget.options?.business ??
        DatabaseService().restaurant?.name ??
        'My business';
    final logo =
        widget.options?.logo ?? DatabaseService().companyLogoPath ?? '';
    final query = _search.text.trim().toLowerCase();
    final groups = (_groups ?? [])
        .where((group) => group.name.toLowerCase().contains(query))
        .toList();
    final loading = _tab == 1 ? _loadingGroups : _loadingCustomers;
    final error = _tab == 1 ? _groupError : _customerError;
    final count = _tab == 1 ? groups.length : _matches;
    return CustomerShell(
      header: const PosScreenTopHeader(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customers',
                            style: customerText(18, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage customers and their groups.',
                            style: customerText(
                              12,
                              color: customerBlue,
                              weight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _stat(
                            'Total customers',
                            _totalCustomers,
                            Icons.people_outline_rounded,
                            const Color(0xFF0884FF),
                            const [Color(0xFFD5F0FF), Color(0xFFA9DFFF)],
                            () => _switchTab(0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _stat(
                            'Groups',
                            _groups?.length,
                            Icons.folder_outlined,
                            customerPurple,
                            const [Color(0xFFEDE0FF), Color(0xFFD1C0FB)],
                            () => _switchTab(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: customerCard(radius: 40),
                      child: Row(
                        children: [
                          _tabButton(0, 'All customers'),
                          _tabButton(1, 'Groups'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: customerCard(radius: 30),
                      child: TextField(
                        controller: _search,
                        onChanged: _searchChanged,
                        style: customerText(13, weight: FontWeight.w500),
                        decoration:
                            customerInput(
                              _tab == 1
                                  ? 'Search groups'
                                  : 'Search by name or mobile',
                              prefix: const Icon(
                                Icons.search_rounded,
                                color: customerInk,
                                size: 19,
                              ),
                              suffix: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        _search.clear();
                                        _searchChanged('');
                                      },
                                    ),
                            ).copyWith(
                              fillColor: Colors.transparent,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          _tab == 1 ? 'Your groups' : 'Your customers',
                          style: customerText(15, weight: FontWeight.w800),
                        ),
                        const Spacer(),
                        CustomerPill(
                          '$count ${_tab == 1 ? (count == 1 ? 'group' : 'groups') : (count == 1 ? 'customer' : 'customers')}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              error,
                              style: customerText(14, color: customerBlue),
                            ),
                            TextButton(
                              onPressed: _tab == 1
                                  ? _loadGroups
                                  : _loadCustomers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!loading && error == null && count == 0)
              SliverToBoxAdapter(child: _empty(query)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: _tab == 1 ? groups.length : _customers.length,
                itemBuilder: (context, index) => _tab == 1
                    ? _groupTile(groups[index], index)
                    : _customerTile(_customers[index]),
              ),
            ),
            if (_tab == 0 && _customers.length < _matches)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(
                    onPressed: _loadingCustomers
                        ? null
                        : () => _loadCustomers(more: true),
                    child: const Text('Load more customers'),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: CustomerPrimary(
                _tab == 1 ? '+ Create group' : 'Add customer',
                icon: Icons.person_add_alt_1_outlined,
                onPressed: _tab == 1 ? () => _editGroup() : _addCustomer,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                _nav(
                  'Home',
                  Icons.home_outlined,
                  widget.onBack ?? () => Navigator.maybePop(context),
                ),
                _nav(
                  'Campaigns',
                  Icons.campaign_outlined,
                  widget.onNavigateToCampaigns ??
                      () => Navigator.maybePop(context),
                ),
                _nav(
                  'Customers',
                  Icons.people_outline_rounded,
                  () {},
                  selected: true,
                ),
                _nav('More', Icons.more_horiz_rounded, _more),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    int? value,
    IconData icon,
    Color color,
    List<Color> colors,
    VoidCallback tap,
  ) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: customerCard(colors: colors, radius: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: color.withValues(alpha: .3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: customerText(10.5, color: customerBlue, weight: FontWeight.w500)),
                  Text(
                    value == null ? '—' : _format.format(value),
                    style: customerText(16, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _tabButton(int index, String title) => Expanded(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _switchTab(index),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.5),
          alignment: Alignment.center,
          decoration: _tab == index
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF216B83), Color(0xFF00394F)],
                  ),
                )
              : null,
          child: Text(
            title,
            style: customerText(
              12.5,
              color: _tab == index ? Colors.white : customerInk,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
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
      (Icons.campaign_outlined, customerPurple, const Color(0xFFDAC6FF)),
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

  Widget _groupTile(AudienceGroupModel group, int index) {
    final (icon, color, background) = _groupStyle(group, index);
    final count = group.totalNumbers;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: customerCard(radius: 15),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => _openGroup(group),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 2, 5),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    CustomerIconTile(
                      icon: icon,
                      color: color,
                      background: background,
                      size: 34,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: const Color(0xFFB2CFE3),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: customerText(13.5, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${_format.format(count)} ${count == 1 ? 'number' : 'numbers'}',
                                style: customerText(
                                  11.5,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              if (constraints.maxWidth < 580)
                                Text(
                                  _updated(group),
                                  style: customerText(
                                    10,
                                    color: customerBlue,
                                    weight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (constraints.maxWidth >= 580) ...[
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: customerBlue,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _updated(group),
                        style: customerText(11.5, weight: FontWeight.w400),
                      ),
                      const SizedBox(width: 10),
                    ],
                    PopupMenuButton<String>(
                      tooltip: 'Options for ${group.name}',
                      iconSize: 18,
                      icon: const Icon(Icons.more_horiz, color: customerBlue, size: 18),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editGroup(group);
                        } else {
                          _deleteGroup(group);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit group')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete group'),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: customerBlue,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerTile(CustomerModel customer) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Container(
      decoration: customerCard(radius: 15),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFD9EBFF),
          foregroundColor: customerBlue,
          child: Text(
            customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          customer.name,
          style: customerText(13.5, weight: FontWeight.w700),
        ),
        subtitle: Text(
          customer.phone,
          style: customerText(11.5, color: customerBlue, weight: FontWeight.w400),
        ),
        trailing: Text(
          '${customer.totalOrders}\n${customer.totalOrders == 1 ? 'order' : 'orders'}',
          textAlign: TextAlign.center,
          style: customerText(11, color: customerBlue),
        ),
      ),
    ),
  );
  Widget _empty(String query) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 35),
    child: Column(
      children: [
        Icon(
          _tab == 1 ? Icons.folder_open_outlined : Icons.people_outline,
          size: 40,
          color: customerBlue,
        ),
        const SizedBox(height: 10),
        Text(
          query.isNotEmpty
              ? 'No matching ${_tab == 1 ? 'groups' : 'customers'}'
              : _tab == 1
              ? 'Create your first customer group'
              : 'Your customers will appear here',
          textAlign: TextAlign.center,
          style: customerText(15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          query.isNotEmpty
              ? 'Try a different search.'
              : _tab == 1
              ? 'Add numbers manually or import a spreadsheet.'
              : 'Add a customer to get started.',
          textAlign: TextAlign.center,
          style: customerText(12, color: customerBlue, weight: FontWeight.w400),
        ),
      ],
    ),
  );
  Widget _nav(
    String label,
    IconData icon,
    VoidCallback tap, {
    bool selected = false,
  }) => Expanded(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF236C83), Color(0xFF00384E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withValues(alpha: .15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : customerBlue,
                size: 19,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: customerText(
                  10,
                  color: selected ? Colors.white : customerBlue,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
