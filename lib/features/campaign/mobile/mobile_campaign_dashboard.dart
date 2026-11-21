import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/campaign_models.dart';
import '../web/views/audience_groups_view.dart';
import '../web/views/campaign_details_monitoring_view.dart';
import '../web/web_campaign_portal_screen.dart';
import 'campaign_editor.dart';
import 'campaign_style.dart';
import 'mobile_campaign_data.dart';
import 'mobile_campaign_performance_screen.dart';
import 'mobile_customers_screen.dart';

class MobileCampaignDashboard extends StatefulWidget {
  final VoidCallback? onBack;
  final MobileCampaignApi? api;
  const MobileCampaignDashboard({super.key, this.onBack, this.api});
  @override
  State<MobileCampaignDashboard> createState() =>
      _MobileCampaignDashboardState();
}

class _MobileCampaignDashboardState extends State<MobileCampaignDashboard> {
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

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    debounce?.cancel();
    poll?.cancel();
    search.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return CampaignShell(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 6),
          children: [
            Center(
              child: Container(
                width: 41,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC1D5E2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.onBack == null && Navigator.of(context).canPop()) ...[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: ink),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                ],
                Text('Campaigns', style: campaignText(29, weight: FontWeight.w800)),
              ],
            ),
            Text(
              'Turn customers into regulars',
              style: campaignText(15, color: muted, weight: FontWeight.w400),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'Sent',
                    NumberFormat.compact().format(sent),
                    Icons.send_outlined,
                    const Color(0xFFE2D8FA),
                    const Color(0xFF7049AE),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    'Read rate',
                    '${sent == 0 ? '0' : (100 * read / sent).toStringAsFixed(1)}%',
                    Icons.check_circle_outline_rounded,
                    const Color(0xFFCBF3DE),
                    const Color(0xFF187348),
                  ),
                ),
              ],
            ),
            _space,
            TextField(
              controller: search,
              onChanged: searchChanged,
              style: campaignText(14),
              decoration: campaignInput(hint: 'Search campaigns').copyWith(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: ink,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (i, e) in const {
                  'all': 'All',
                  'scheduled': 'Scheduled',
                  'completed': 'Completed',
                }.entries.indexed) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: InkWell(
                      onTap: () => setFilter(e.key),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: campaignCard(
                          color: filter == e.key
                              ? teal
                              : const Color(0xFFF6FAFE),
                          radius: 20,
                        ),
                        child: Text(
                          e.value,
                          style: campaignText(
                            13,
                            color: filter == e.key ? Colors.white : ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            _space,
            if (loading) const LinearProgressIndicator(minHeight: 2),
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
            if (!loading && error == null && rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    filter == 'all' && search.text.isEmpty
                        ? 'Your campaigns will appear here'
                        : 'No matching campaigns',
                    style: campaignText(14, color: muted),
                  ),
                ),
              ),
            for (final c in rows) _campaignRow(c),
            if (rows.length < total && !loading)
              TextButton(
                onPressed: () => load(more: true),
                child: const Text('Load more campaigns'),
              ),
            if (rows.isNotEmpty)
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
                    Text(
                      'Tap a campaign to view performance.',
                      style: campaignText(12, color: muted, weight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      footer: Container(
        padding: const EdgeInsets.fromLTRB(13, 7, 13, 5),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: CampaignPrimary(
                'Create campaign',
                icon: Icons.add_rounded,
                onTap: options == null ? null : () => edit(),
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
                  _nav('Campaigns', Icons.campaign_rounded, () {
                    search.clear();
                    setFilter('all');
                  }, selected: true),
                  _nav(
                    'Customers',
                    Icons.people_alt_outlined,
                    () => openAux(
                      (ctx) => MobileCustomersScreen(
                        options: options,
                        onBack: () => Navigator.pop(ctx),
                        onNavigateToCampaigns: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                  _nav(
                    'More',
                    Icons.more_horiz,
                    () => openAux(
                      (ctx) => WebCampaignPortalScreen(
                        onBack: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campaignRow(CampaignJson c) {
    final r = c['rewardDetails'] ?? {}, raw = c['status'] ?? 'draft';
    final kind = switch (r['rewardType']) {
      'percent_discount' => 'percentage',
      'flat_cash' => 'flat_discount',
      final String s => s,
      _ => '',
    };
    final style = rewardStyles[kind] ?? rewardStyles['promotional']!;
    final label = switch (raw) {
      'in_review' => 'In review',
      'scheduled'
          when c['mobileStudio'] != null && c['schedule']?['mode'] != 'later' =>
        'Queued',
      'sent' => 'Completed',
      _ => raw[0].toUpperCase() + raw.substring(1),
    };
    final isCompleted = raw == 'completed' || raw == 'sent';
    final badge = switch (raw) {
      'scheduled' => const Color(0xFFFFE3CA),
      'completed' || 'sent' => const Color(0xFFCEF3DA),
      'failed' => const Color(0xFFFFDAD4),
      _ => const Color(0xFFD7EBFD),
    };
    final badgeTextColor = switch (raw) {
      'completed' || 'sent' => const Color(0xFF15803D),
      'scheduled' => const Color(0xFFC05621),
      'failed' => const Color(0xFFDC2626),
      _ => ink,
    };
    final offer = switch (kind) {
      'percentage' => '${campaignNumber(r['discountAmount'])}% OFF',
      'flat_discount' => 'Flat ₹${campaignNumber(r['discountAmount'])} OFF',
      _ => style.$1,
    };
    final at = DateTime.tryParse(
      c['schedule']?['sentAt']?.toString() ??
          c['schedule']?['scheduledAt']?.toString() ??
          c['createdAt']?.toString() ??
          '',
    );
    final note = c['mobileStudio']?['note'] ?? '';
    final recipientsCount = c['audience']?['recipientCount'] ??
        c['audience']?['count'] ??
        (c['stats']?['totalRecipients'] ?? 0);
    final deliveryRate = (c['stats']?['deliveryRate'] as num?)?.toDouble() ?? 95.2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => showCampaign(c),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: campaignCard(),
          child: Row(
            children: [
              CampaignIconTile(style.$2, style.$4, style.$3, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Expanded(
                      child: Text(
                        c['name'],
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
                        color: badge,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        label,
                        style: campaignText(
                          11,
                          color: badgeTextColor,
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
                  [
                    if (r['rewardType'] != null) offer,
                    'WhatsApp',
                  ].join(' · '),
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
                      '${NumberFormat.decimalPattern('en_IN').format(recipientsCount)} recipients',
                    ),
                    if (at != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text('|', style: TextStyle(color: borderBlue, fontSize: 11)),
                      ),
                      _meta(
                        Icons.calendar_today_outlined,
                        DateFormat('d MMM · h:mm a').format(indiaClock(at)),
                      ),
                    ],
                  ],
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Delivered ${deliveryRate.toStringAsFixed(1)}%',
                      style: campaignText(
                        11,
                        color: const Color(0xFF0284C7),
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (raw == 'approved' &&
                    c['mobileStudio'] != null &&
                    c['template']?['category'] != 'AUTHENTICATION')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Send to customers'),
                      onPressed: () => edit(c),
                    ),
                  ),
                if (note.isNotEmpty &&
                    (raw != 'approved' ||
                        note != 'Approved by Meta. Ready to send.'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note,
                      style: campaignText(11, color: muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}
}

const _space = SizedBox(height: 12);
Widget _metric(String label, String value, IconData icon, Color bg, Color fg) =>
    Container(
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
    );
Widget _meta(IconData icon, String value) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, color: muted, size: 14),
    const SizedBox(width: 4),
    Text(value, style: campaignText(11)),
  ],
);
Widget _nav(
  String label,
  IconData icon,
  VoidCallback tap, {
  bool selected = false,
}) => Expanded(
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
