import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/campaign_models.dart';
import 'campaign_editor.dart';
import 'campaign_style.dart';
import 'mobile_campaign_data.dart';
import 'mobile_campaign_performance_screen.dart';
import 'mobile_customers_screen.dart';

class MobileCampaignDashboard extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToCustomers;
  final MobileCampaignApi? api;
  const MobileCampaignDashboard({
    super.key,
    this.onBack,
    this.onNavigateToCustomers,
    this.api,
  });
  @override
  State<MobileCampaignDashboard> createState() =>
      _MobileCampaignDashboardState();
}

class _MobileCampaignDashboardState extends State<MobileCampaignDashboard>
    with SingleTickerProviderStateMixin {
  late final api = widget.api ?? MobileCampaignApi();
  final search = TextEditingController();
  Timer? debounce;
  Timer? poll;
  CampaignOptions? options;
  List<CampaignJson> rows = [];
  int sent = 0, read = 0, total = 0, page = 1, sequence = 0;
  bool loading = true;
  String filter = 'all';
  String? error, optionsError;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    refresh();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    debounce?.cancel();
    poll?.cancel();
    search.dispose();
    super.dispose();
  }

  Widget _shimmerBox(double height, {double? width, double radius = 12}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _skeletonCampaignCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(44, width: 44, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _shimmerBox(16, radius: 4)),
                      const SizedBox(width: 12),
                      _shimmerBox(20, width: 68, radius: 10),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _shimmerBox(12, width: 130, radius: 4),
                  const SizedBox(height: 8),
                  _shimmerBox(12, width: 180, radius: 4),
                  const SizedBox(height: 10),
                  _shimmerBox(22, width: 110, radius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadOptions() async {
    try {
      final value = await api.options();
      if (mounted) {
        setState(() {
          options = value;
          optionsError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => optionsError = e.toString());
    }
  }

  Future<void> refresh() => Future.wait([loadOptions(), load()]);

  Future<void> load({bool more = false}) async {
    final revision = ++sequence;
    final targetPage = more ? page + 1 : 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.dashboard(search.text.trim(), filter, targetPage);
      if (!mounted || revision != sequence) return;
      final list = List<CampaignJson>.from(data['campaigns']);
      setState(() {
        rows = more ? [...rows, ...list] : list;
        total = data['total'];
        page = targetPage;
        sent = data['sent'];
        read = data['read'];
      });
      poll?.cancel();
      if (page == 1 &&
          rows.any(
            (row) => [
              'in_review',
              'scheduled',
              'processing',
            ].contains(row['status']),
          )) {
        poll = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted &&
              !loading &&
              TickerMode.valuesOf(context).enabled &&
              ModalRoute.of(context)?.isCurrent != false) {
            load();
          }
        });
      }
    } catch (e) {
      if (mounted && revision == sequence) setState(() => error = e.toString());
    } finally {
      if (mounted && revision == sequence) setState(() => loading = false);
    }
  }

  void searchChanged(String _) {
    debounce?.cancel();
    sequence++;
    debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) load();
    });
  }

  void setFilter(String value) {
    debounce?.cancel();
    setState(() => filter = value);
    load();
  }

  Future<void> edit([CampaignJson? existing]) async {
    if (options == null || existing?['status'] == 'approved') {
      await loadOptions();
      if (!mounted || options == null) return;
    }
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CampaignEditor(
          api: api,
          approved: existing?['status'] == 'approved',
          options: options!,
          draft: existing == null
              ? MobileCampaignDraft()
              : MobileCampaignDraft.fromJson(existing),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      search.clear();
      filter = 'all';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
    await load();
  }

  Future<void> openAux(Widget Function(BuildContext) builder) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    if (mounted) await refresh();
  }

  Future<void> showCampaign(CampaignJson c) async {
    if (c['status'] == 'draft' ||
        (c['mobileStudio'] != null &&
            c['status'] == 'approved' &&
            c['template']?['category'] != 'AUTHENTICATION')) {
      await edit(c);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MobileCampaignPerformanceScreen(
          campaign: c,
          options: options,
          api: api,
          onRefreshDashboard: refresh,
        ),
      ),
    );
    if (mounted) await load();
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
            title: const Text('Refresh campaigns'),
            onTap: () {
              Navigator.pop(sheetContext);
              refresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded),
            title: const Text('Create campaign'),
            onTap: () {
              Navigator.pop(sheetContext);
              if (options != null) edit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Go to customers'),
            onTap: () {
              Navigator.pop(sheetContext);
              if (widget.onNavigateToCustomers != null) {
                widget.onNavigateToCustomers!();
              } else {
                openAux(
                  (ctx) => MobileCustomersScreen(
                    options: options,
                    showHeader: true,
                    onBack: () => Navigator.pop(ctx),
                    onNavigateToCampaigns: () => Navigator.pop(ctx),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isInitialLoading = loading && rows.isEmpty;
    final displayRows = rows;

    final displaySent = sent;
    final displayReadRate = sent == 0 ? '0%' : '${(100 * read / sent).toStringAsFixed(1)}%';

    return Container(
      color: const Color(0xFFEDF3FA),
      child: CampaignShell(
        body: RefreshIndicator(
          onRefresh: refresh,
          color: const Color(0xFF0077B6),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            children: [
              const SizedBox(height: 8),

              // Header Row: Title & Subtitle on left, 3D Megaphone Graphic on right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.onBack == null && Navigator.of(context).canPop()) ...[
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F1E36)),
                                tooltip: 'Back',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Flexible(
                              child: Text(
                                'Campaigns',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F1E36),
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Turn customers into regulars',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _Megaphone3DGraphic(),
                ],
              ),
              const SizedBox(height: 16),

              // Top 2 Metric Cards: Total Sent & Read Rate
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      label: 'Total Sent',
                      value: NumberFormat.compact().format(displaySent),
                      icon: Icons.near_me_rounded,
                      gradient: const [Color(0xFFF3EEFE), Color(0xFFE6DCFD)],
                      iconColor: const Color(0xFF8B5CF6),
                      isLoading: isInitialLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      label: 'Read Rate',
                      value: displayReadRate,
                      icon: Icons.check_circle_rounded,
                      gradient: const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                      iconColor: const Color(0xFF10B981),
                      showBarChart: true,
                      isLoading: isInitialLoading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Input & Filter Button
              Row(
                children: [
                  Expanded(
                    child: Container(
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
                        controller: search,
                        onChanged: searchChanged,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          color: Color(0xFF0F1E36),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search campaigns...',
                          hintStyle: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _more,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0B2545).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.filter_alt_outlined,
                          color: Color(0xFF0F1E36),
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Tabs Row (All / Scheduled / Completed)
              Row(
                children: [
                  for (final (i, e) in const {
                    'all': 'All',
                    'scheduled': 'Scheduled',
                    'completed': 'Completed',
                  }.entries.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _filterPill(
                        keyName: e.key,
                        label: e.value,
                        selected: filter == e.key,
                        icon: switch (e.key) {
                          'scheduled' => Icons.calendar_today_outlined,
                          'completed' => Icons.check_circle_outline_rounded,
                          _ => Icons.layers_rounded,
                        },
                        onTap: () => setFilter(e.key),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              if (isInitialLoading) ...[
                _skeletonCampaignCard(),
                _skeletonCampaignCard(),
                _skeletonCampaignCard(),
              ] else ...[
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2.5,
                      color: Color(0xFF0077B6),
                      backgroundColor: Color(0xFFE0F2FE),
                    ),
                  ),

                if (error != null || optionsError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text(error ?? optionsError!, style: campaignText(13)),
                        TextButton(onPressed: refresh, child: const Text('Retry')),
                      ],
                    ),
                  ),

                if (!loading && error == null && displayRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        filter == 'all' && search.text.isEmpty
                            ? 'Your campaigns will appear here'
                            : 'No matching campaigns',
                        style: campaignText(14, color: muted),
                      ),
                    ),
                  ),

                for (final c in displayRows) _campaignRow(c),

                if (rows.length < total && !loading && rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: TextButton(
                        onPressed: () => load(more: true),
                        child: const Text('Load more campaigns'),
                      ),
                    ),
                  ),

                if (displayRows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: muted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Tap a campaign to view performance.',
                            style: campaignText(11.5, color: muted, weight: FontWeight.w400),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        footer: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Floating "+ Create campaign" Button
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
                      onTap: options == null ? null : () => edit(),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Create campaign',
                              style: TextStyle(
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

              // Bottom Navigation Bar
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
                      icon: Icons.campaign_rounded,
                      selected: true,
                      onTap: () {
                        search.clear();
                        setFilter('all');
                      },
                    ),
                    _navItem(
                      label: 'Customers',
                      icon: Icons.people_alt_outlined,
                      onTap: widget.onNavigateToCustomers ??
                          () => openAux(
                            (ctx) => MobileCustomersScreen(
                              options: options,
                              showHeader: true,
                              onBack: () => Navigator.pop(ctx),
                              onNavigateToCampaigns: () => Navigator.pop(ctx),
                            ),
                          ),
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
        ),
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    required Color iconColor,
    bool showBarChart = false,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.18),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                if (isLoading)
                  _shimmerBox(22, width: 50, radius: 5)
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F1E36),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                      if (showBarChart) ...[
                        const SizedBox(width: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 3.5,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 2.5),
                            Container(
                              width: 3.5,
                              height: 13,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 2.5),
                            Container(
                              width: 3.5,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String keyName,
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8.5, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                icon,
                size: 14,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF0F1E36),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campaignRow(CampaignJson c) {
    final raw = c['status'] ?? 'draft';
    final isApproved = raw == 'approved';
    final isCompleted = raw == 'completed' || raw == 'sent';
    final isScheduled = raw == 'scheduled';

    final label = switch (raw) {
      'in_review' => 'In review',
      'scheduled'
          when c['mobileStudio'] != null && c['schedule']?['mode'] != 'later' =>
        'Queued',
      'sent' => 'Completed',
      'approved' => 'Approved',
      _ => raw[0].toUpperCase() + raw.substring(1),
    };

    final at = DateTime.tryParse(
      c['schedule']?['sentAt']?.toString() ??
          c['schedule']?['scheduledAt']?.toString() ??
          c['createdAt']?.toString() ??
          '',
    );
    final note = c['mobileStudio']?['note'] ?? '';
    final category = campaignCategories[(c['template']?['category'] ?? c['type'] ?? '').toString().toUpperCase()] ?? (c['type']?.toString().isNotEmpty == true ? c['type'].toString() : 'Marketing');
    final stats = (c['stats'] as Map<String, dynamic>?) ?? {};
    final num sentCount = (stats['messagesSent'] ?? stats['sent'] ?? 0) as num;
    final num deliveredCount = (stats['delivered'] ?? 0) as num;
    final num failedCount = (stats['failed'] ?? 0) as num;
    final recipientsCount = c['audience']?['recipientCount'] ??
        c['audience']?['count'] ??
        ((stats['totalRecipients'] as num?)?.toInt() ?? 0);

    final num totalAttempted = (stats['totalRecipients'] as num?)?.toInt() ??
        (recipientsCount > 0 ? recipientsCount : (sentCount + failedCount));

    double deliveryRate;
    if (totalAttempted > 0) {
      if (failedCount > 0) {
        final num successful = (totalAttempted - failedCount).clamp(0, totalAttempted);
        deliveryRate = (successful / totalAttempted) * 100.0;
      } else if (deliveredCount > 0) {
        deliveryRate = (deliveredCount / totalAttempted) * 100.0;
      } else if (sentCount > 0) {
        deliveryRate = (sentCount / totalAttempted) * 100.0;
      } else {
        deliveryRate = 0.0;
      }
    } else {
      deliveryRate = (stats['deliveryRate'] as num?)?.toDouble() ?? 0.0;
    }
    deliveryRate = deliveryRate.clamp(0.0, 100.0);

    final useMegaphoneBadge = isApproved ||
        (c['type']?.toString().toLowerCase() == 'promotional') ||
        (c['template']?['category']?.toString().toUpperCase() == 'PROMOTIONAL');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          onTap: () => showCampaign(c),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left 3D style badge
                    if (useMegaphoneBadge)
                      const _MegaphoneSquircleBadge()
                    else
                      const _DiscountTagBadge(),
                    const SizedBox(width: 10),

                    // Right campaign information column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Title + Status Pill Badge + Chevron
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c['name'] ?? 'Campaign',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F1E36),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              // Status pill badge matching mockup
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? const Color(0xFFDCFCE7)
                                      : isApproved
                                      ? const Color(0xFFDBEAFE)
                                      : isScheduled
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCompleted) ...[
                                      Container(
                                        width: 5.5,
                                        height: 5.5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF16A34A),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ] else if (isApproved) ...[
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 11.5,
                                        color: Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isCompleted
                                            ? const Color(0xFF15803D)
                                            : isApproved
                                            ? const Color(0xFF1D4ED8)
                                            : isScheduled
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFF6D28D9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 17,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Row 2: WhatsApp icon + WhatsApp · Marketing/Category
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/whatsapp_logo.png',
                                width: 13.5,
                                height: 13.5,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 12.5,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  isApproved
                                      ? 'Promotional  •  WhatsApp'
                                      : 'WhatsApp  •  $category',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Row 3: Audience + Date (if approved) or Sent Date
                          if (isApproved)
                            Wrap(
                              spacing: 5,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_alt_outlined,
                                      size: 12.5,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3.5),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                        children: [
                                          const TextSpan(text: 'Audience: '),
                                          TextSpan(
                                            text: NumberFormat.decimalPattern('en_IN').format(recipientsCount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F1E36),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3.5),
                                    Flexible(
                                      child: Text(
                                        at != null
                                            ? DateFormat('d MMM yyyy, h:mm a').format(indiaClock(at))
                                            : '29 Nov 2026, 5:30 PM',
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else if (at != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${isCompleted ? "Sent: " : ""}${DateFormat("d MMM yyyy, h:mm a").format(indiaClock(at))}',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          // Row 4: Stats Row (Delivered pill + Audience count)
                          if (isCompleted) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 11.5,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        'Delivered: ${deliveryRate.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_alt_outlined,
                                      size: 12.5,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3.5),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                        children: [
                                          const TextSpan(text: 'Audience: '),
                                          TextSpan(
                                            text: NumberFormat.decimalPattern('en_IN').format(recipientsCount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F1E36),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Button for approved campaign ("Send campaign")
                if (isApproved &&
                    c['template']?['category'] != 'AUTHENTICATION') ...[
                  const SizedBox(height: 11),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => edit(c),
                      child: Container(
                        width: double.infinity,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0B2545).withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.near_me_outlined,
                              size: 15,
                              color: Color(0xFF0077B6),
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Send campaign',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0077B6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                if (raw == 'draft' && c['template']?['metaStatus'] == 'REJECTED' && c['mobileStudio'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Check template approval'),
                      onPressed: () async {
                        try {
                          await api.submit(MobileCampaignDraft.fromJson(c));
                          if (mounted) await load();
                        } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not check approval. Refresh and try again.')));
                        }
                      },
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
            padding: const EdgeInsets.symmetric(vertical: 7),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
}

/// Sky blue squircle badge with discount coupon tag (%) and sparkle dots
class _DiscountTagBadge extends StatelessWidget {
  final double size;
  const _DiscountTagBadge({this.size = 50});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DiscountTagPainter(),
      ),
    );
  }
}

class _DiscountTagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Sparkle Diamond at Top-Left
    final sparklePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    final diamondPath = Path();
    const sx = 14.0;
    const sy = 14.0;
    diamondPath.moveTo(sx, sy - 3.5);
    diamondPath.lineTo(sx + 2.5, sy);
    diamondPath.lineTo(sx, sy + 3.5);
    diamondPath.lineTo(sx - 2.5, sy);
    diamondPath.close();
    canvas.drawPath(diamondPath, sparklePaint);

    // 2. Sparkle Dot at Top-Right
    canvas.drawCircle(const Offset(36, 13), 1.8, sparklePaint);

    // 3. Angled Price Tag
    canvas.save();
    canvas.translate(cx, cy + 1);
    canvas.rotate(-0.45); // ~ -26 degrees

    // Tag body (rounded rectangle)
    final tagPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
      ).createShader(const Rect.fromLTWH(-11, -14, 22, 28));

    final tagRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -14, 22, 28),
      const Radius.circular(5),
    );
    canvas.drawRRect(tagRRect, tagPaint);

    // Small punch hole at top
    final holePaint = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -9), 2.2, holePaint);

    // "%" Text inside the tag
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '%',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2 + 3),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Peach/warm orange squircle badge with megaphone and sound waves
class _MegaphoneSquircleBadge extends StatelessWidget {
  final double size;
  const _MegaphoneSquircleBadge({this.size = 50});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _MegaphoneSquirclePainter(),
      ),
    );
  }
}

class _MegaphoneSquirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final orangePaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(cx - 3, cy + 1);
    canvas.rotate(-0.35); // angle slightly up-right

    // Megaphone Cone
    final conePath = Path();
    conePath.moveTo(-10, -4);
    conePath.lineTo(8, -10);
    conePath.lineTo(10, 8);
    conePath.lineTo(-8, 5);
    conePath.close();
    canvas.drawPath(conePath, orangePaint);

    // Front horn mouth (oval)
    canvas.drawOval(
      const Rect.fromLTWH(6, -11, 6, 20),
      orangePaint,
    );

    // Rear base
    canvas.drawOval(
      const Rect.fromLTWH(-12, -5, 4, 11),
      orangePaint,
    );

    // Handle
    final handlePath = Path();
    handlePath.moveTo(-4, 4);
    handlePath.lineTo(-2, 13);
    handlePath.lineTo(2, 12);
    handlePath.lineTo(0, 3);
    handlePath.close();
    canvas.drawPath(handlePath, orangePaint);

    canvas.restore();

    // Sound waves
    final wavePaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Inner wave arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx + 3, cy - 1), radius: 11),
      -0.6,
      1.1,
      false,
      wavePaint,
    );

    // Outer wave arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx + 3, cy - 1), radius: 15),
      -0.5,
      0.9,
      false,
      wavePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Megaphone Graphic with sound bursts matching the design mockup
class _Megaphone3DGraphic extends StatelessWidget {
  const _Megaphone3DGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Soft oval cloud background with subtle shadow
          Container(
            width: 78,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          // Custom 3D Isometric Megaphone Painter
          Positioned.fill(
            child: CustomPaint(
              painter: _IsometricMegaphonePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _IsometricMegaphonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.44;
    final cy = size.height * 0.52;

    // 1. Megaphone Handle (Teal)
    final handlePaint = Paint()
      ..color = const Color(0xFF0096C7)
      ..style = PaintingStyle.fill;
    final handlePath = Path();
    handlePath.moveTo(cx - 5, cy + 5);
    handlePath.lineTo(cx - 10, cy + 18);
    handlePath.lineTo(cx - 3, cy + 19);
    handlePath.lineTo(cx + 1, cy + 5);
    handlePath.close();
    canvas.drawPath(handlePath, handlePaint);

    // 2. Rear Collar Ring & Cap
    final collarPaint = Paint()
      ..color = const Color(0xFF0077B6)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 13, cy + 5), width: 8, height: 14),
      collarPaint,
    );
    final capPaint = Paint()
      ..color = const Color(0xFF023E8A)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 15, cy + 6), width: 5, height: 11),
      capPaint,
    );

    // 3. Megaphone Cone (Body - White shaded to silver-blue)
    final conePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFF1F5F9), Color(0xFFCBD5E1)],
      ).createShader(Rect.fromLTWH(cx - 15, cy - 14, 30, 26));

    final conePath = Path();
    conePath.moveTo(cx - 12, cy - 1);
    conePath.lineTo(cx + 9, cy - 12);
    conePath.lineTo(cx + 13, cy + 10);
    conePath.lineTo(cx - 9, cy + 9);
    conePath.close();
    canvas.drawPath(conePath, conePaint);

    // 4. Front Horn Mouth Rim (3D Ring in bright cyan/teal)
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
      ).createShader(Rect.fromLTWH(cx + 6, cy - 14, 14, 26));

    final mouthCenter = Offset(cx + 12, cy - 1);
    canvas.drawOval(
      Rect.fromCenter(center: mouthCenter, width: 13, height: 25),
      rimPaint,
    );

    // Inner horn depth (darker teal)
    final innerPaint = Paint()
      ..color = const Color(0xFF004E64)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: mouthCenter, width: 9, height: 19),
      innerPaint,
    );

    // Center dome (white)
    final domePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: mouthCenter, width: 4, height: 7),
      domePaint,
    );

    // 5. Sound Wave Bursts (Bright Yellow/Gold #FBBF24)
    final rayPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Ray 1 (Top right)
    canvas.drawLine(
      Offset(mouthCenter.dx + 9, mouthCenter.dy - 8),
      Offset(mouthCenter.dx + 16, mouthCenter.dy - 14),
      rayPaint,
    );

    // Ray 2 (Middle right)
    canvas.drawLine(
      Offset(mouthCenter.dx + 11, mouthCenter.dy),
      Offset(mouthCenter.dx + 19, mouthCenter.dy),
      rayPaint,
    );

    // Ray 3 (Bottom right)
    canvas.drawLine(
      Offset(mouthCenter.dx + 9, mouthCenter.dy + 8),
      Offset(mouthCenter.dx + 15, mouthCenter.dy + 14),
      rayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
