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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 6),
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: ink),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
              ],
              Text('Customers', style: campaignText(29, weight: FontWeight.w800)),
            ],
          ),
            Text(
              'Manage customers and their groups.',
              style: campaignText(15, color: muted, weight: FontWeight.w400),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _metric(
                  'Total customers',
                  _totalCustomers == null ? '—' : _format.format(_totalCustomers),
                  Icons.people_alt_outlined,
                  const Color(0xFFE2D8FA),
                  const Color(0xFF7049AE),
                  onTap: () => _switchTab(0),
                ),
                const SizedBox(width: 10),
                _metric(
                  'Groups',
                  '${_groups?.length ?? 0}',
                  Icons.folder_outlined,
                  const Color(0xFFCBF3DE),
                  const Color(0xFF187348),
                  onTap: () => _switchTab(1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: _searchChanged,
              style: campaignText(14),
              decoration: campaignInput(
                hint: _tab == 1
                    ? 'Search groups'
                    : 'Search by name or mobile',
              ).copyWith(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: ink,
                  size: 20,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          _searchChanged('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (i, e) in const {
                  0: 'All customers',
                  1: 'Groups',
                }.entries.indexed) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: InkWell(
                      onTap: () => _switchTab(e.key),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: campaignCard(
                          color: _tab == e.key
                              ? teal
                              : const Color(0xFFF6FAFE),
                          radius: 20,
                        ),
                        child: Text(
                          e.value,
                          style: campaignText(
                            13,
                            color: _tab == e.key ? Colors.white : ink,
                            weight: _tab == e.key
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _tab == 1 ? 'Your groups' : 'Your customers',
                  style: campaignText(14, weight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count ${_tab == 1 ? (count == 1 ? 'group' : 'groups') : (count == 1 ? 'customer' : 'customers')}',
                    style: campaignText(
                      11,
                      color: const Color(0xFF0284C7),
                      weight: FontWeight.w700,
                    ),
                  ),
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Text(error, style: campaignText(13, color: muted)),
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

    final footerWidget = Padding(
      padding: const EdgeInsets.fromLTRB(15, 6, 15, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: CampaignPrimary(
              _tab == 1 ? 'Create group' : 'Add customer',
              icon: Icons.add_rounded,
              onTap: _tab == 1 ? () => _editGroup() : _addCustomer,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: campaignCard(
              radius: 15,
              color: const Color(0xFFF5FAFE),
            ),
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
                  Icons.people_alt_rounded,
                  () {
                    _search.clear();
                    _switchTab(0);
                  },
                  selected: true,
                ),
                _nav('More', Icons.more_horiz_rounded, _more),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.showHeader) {
      return CustomerShell(
        header: const PosScreenTopHeader(),
        body: bodyWidget,
        footer: footerWidget,
      );
    }

    return CampaignShell(
      body: bodyWidget,
      footer: footerWidget,
    );
  }

  Widget _metric(
    String label,
    String value,
    IconData icon,
    Color bg,
    Color fg, {
    VoidCallback? onTap,
  }) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white),
              boxShadow: const [studioShadow],
            ),
            child: Row(
              children: [
                CampaignIconTile(
                  icon,
                  Colors.white.withValues(alpha: .45),
                  fg,
                  size: 37,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: campaignText(12)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: campaignText(24, weight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _meta(IconData icon, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: muted, size: 14),
          const SizedBox(width: 4),
          Text(value, style: campaignText(11)),
        ],
      );

  Widget _groupCard(AudienceGroupModel group, int index) {
    final (icon, color, background) = _groupStyle(group, index);
    final count = group.totalNumbers;
    final isVip = group.name.toLowerCase().contains('vip');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openGroup(group),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: campaignCard(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampaignIconTile(icon, background, color, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: campaignText(15, weight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isVip
                                ? const Color(0xFFFFE3CA)
                                : const Color(0xFFD7EBFD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVip ? 'VIP' : 'Group',
                            style: campaignText(
                              11,
                              color: isVip ? const Color(0xFFC05621) : ink,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_format.format(count)} ${count == 1 ? 'number' : 'numbers'} · Audience Group',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: campaignText(
                        12,
                        color: muted,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _meta(
                          Icons.people_alt_outlined,
                          '${_format.format(count)} numbers',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            '|',
                            style: TextStyle(color: borderBlue, fontSize: 11),
                          ),
                        ),
                        _meta(
                          Icons.calendar_today_outlined,
                          _updated(group),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Ready for campaigns',
                            style: campaignText(
                              11,
                              color: const Color(0xFF0284C7),
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          tooltip: 'Options for ${group.name}',
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                          icon: const Icon(Icons.more_horiz, color: muted, size: 18),
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
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerCard(CustomerModel customer) {
    final isVip = customer.totalOrders >= 5;
    final isMember = customer.totalOrders > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: campaignCard(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CampaignIconTile(
              Icons.person_rounded,
              Color(0xFFDCF0FF),
              Color(0xFF1572C3),
              size: 44,
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
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: campaignText(15, weight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isVip
                              ? const Color(0xFFFFE3CA)
                              : (isMember
                                  ? const Color(0xFFCEF3DA)
                                  : const Color(0xFFD7EBFD)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isVip ? 'VIP' : (isMember ? 'Member' : 'New'),
                          style: campaignText(
                            11,
                            color: isVip
                                ? const Color(0xFFC05621)
                                : (isMember ? const Color(0xFF15803D) : ink),
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: campaignText(
                      12,
                      color: muted,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _meta(
                        Icons.shopping_bag_outlined,
                        '${customer.totalOrders} ${customer.totalOrders == 1 ? 'order' : 'orders'}',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          '|',
                          style: TextStyle(color: borderBlue, fontSize: 11),
                        ),
                      ),
                      _meta(
                        Icons.verified_user_outlined,
                        'Customer Profile',
                      ),
                    ],
                  ),
                  if (isMember) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Active Buyer',
                        style: campaignText(
                          11,
                          color: const Color(0xFF0284C7),
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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

  Widget _nav(
    String label,
    IconData icon,
    VoidCallback tap, {
    bool selected = false,
  }) =>
      Expanded(
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
