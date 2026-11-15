import 'package:flutter/material.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../models/campaign_models.dart';

const _ink = Color(0xFF132B4C);
const _purple = Color(0xFF7047D6);
const _muted = Color(0xFF637189);

class CampaignStudioLayout extends StatelessWidget {
  final CampaignStatsModel stats;
  final List<CampaignModel> campaigns;
  final List<CampaignTemplateModel> templates;
  final List<String> categories;
  final Map<String, int> counts;
  final String tab, category;
  final bool loading;
  final VoidCallback onCreate, onAuto, onGroups, onTopUp, onPerformance;
  final ValueChanged<String> onTab, onCategory, onSearch;
  final ValueChanged<CampaignModel> onCampaign;
  final ValueChanged<CampaignTemplateModel> onTemplate;
  final Future<void> Function() onRefresh;
  const CampaignStudioLayout({
    super.key,
    required this.stats,
    required this.campaigns,
    required this.templates,
    required this.categories,
    required this.counts,
    required this.tab,
    required this.category,
    required this.loading,
    required this.onCreate,
    required this.onAuto,
    required this.onGroups,
    required this.onTopUp,
    required this.onPerformance,
    required this.onTab,
    required this.onCategory,
    required this.onSearch,
    required this.onCampaign,
    required this.onTemplate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF3F2FC),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: _purple,
                          ),
                        ),
                      LayoutBuilder(
                        builder: (_, constraints) => constraints.maxWidth >= 850
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 6, child: _hero()),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 4, child: _performance()),
                                ],
                              )
                            : Column(
                                children: [
                                  _hero(),
                                  const SizedBox(height: 16),
                                  _performance(),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: counts.entries
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    selected: tab == entry.key,
                                    label: Text(
                                      entry.key +
                                          (entry.value > 0
                                              ? ' (${entry.value})'
                                              : ''),
                                    ),
                                    onSelected: (_) => onTab(entry.key),
                                    showCheckmark: false,
                                    selectedColor: _ink,
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: tab == entry.key
                                          ? Colors.white
                                          : _ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    side: BorderSide(
                                      color: tab == entry.key
                                          ? _ink
                                          : const Color(0xFFE0DEEF),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (tab == 'Explore Campaigns') ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories
                                .map(
                                  (label) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      selected: category == label,
                                      showCheckmark: false,
                                      onSelected: (_) => onCategory(label),
                                      label: Text(label),
                                      selectedColor: const Color(0xFFE7DCFF),
                                      backgroundColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color: category == label
                                            ? _purple
                                            : _muted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                      side: BorderSide.none,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          onChanged: onSearch,
                          decoration: InputDecoration(
                            hintText: 'Search campaign templates',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0DEEF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Campaign templates',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ready-made messages for your next campaign.',
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ] else ...[
                        Text(
                          tab,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Review your campaigns and track their progress.',
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (tab == 'Explore Campaigns' && templates.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverLayoutBuilder(
                    builder: (_, constraints) {
                      final columns = constraints.crossAxisExtent < 520
                          ? 2
                          : constraints.crossAxisExtent < 850
                          ? 3
                          : 4;
                      return SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (_, index) => _template(templates[index]),
                          childCount: templates.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 286,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                      );
                    },
                  ),
                )
              else if (tab != 'Explore Campaigns' && campaigns.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList.builder(
                    itemCount: campaigns.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _campaign(campaigns[index]),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                    child: _empty(),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _surface(Widget child, {Color color = Colors.white}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE1DFEF)),
    ),
    child: child,
  );

  Widget _hero() => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.campaign_rounded, color: _purple, size: 16),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'CAMPAIGN STUDIO',
                style: TextStyle(
                  color: _purple,
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reach customers.\nGrow your orders.',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Create WhatsApp offers and updates in minutes.',
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Image.asset(
                'assets/images/campaign_hero_phone_3d.png',
                height: 150,
                fit: BoxFit.contain,
                cacheWidth: 600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create new campaign'),
          style: FilledButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _secondary(
                'Auto campaigns',
                Icons.auto_awesome_outlined,
                onAuto,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _secondary(
                'Audience groups',
                Icons.groups_outlined,
                onGroups,
              ),
            ),
          ],
        ),
      ],
    ),
    color: const Color(0xFFFAF8FF),
  );

  Widget _secondary(
    String label,
    IconData icon,
    VoidCallback action,
  ) => OutlinedButton(
    onPressed: action,
    style: OutlinedButton.styleFrom(
      foregroundColor: _ink,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      side: const BorderSide(color: Color(0xFFE1DFEF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _performance() => _surface(
    Column(
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: _purple, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Campaign performance',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              tooltip: 'View campaign performance',
              onPressed: onPerformance,
              icon: const Icon(
                Icons.arrow_outward_rounded,
                size: 17,
                color: _muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Drafts',
                stats.draftCount,
                Icons.edit_note_rounded,
                const Color(0xFFEEE6FF),
                'Drafts',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric(
                'Approved',
                stats.approvedCount,
                Icons.check_circle_outline,
                const Color(0xFFE4F7EC),
                'Approved',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Scheduled',
                stats.scheduledCount,
                Icons.calendar_today_outlined,
                const Color(0xFFE6EEFF),
                'Scheduled',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric(
                'Pending',
                stats.pendingCount,
                Icons.schedule_rounded,
                const Color(0xFFFFF0DC),
                'Pending',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F3FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 21,
                color: _purple,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet balance',
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                    Text(
                      '₹${stats.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onTopUp,
                child: const Text(
                  'Top up',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _metric(
    String label,
    int count,
    IconData icon,
    Color color,
    String filter,
  ) => Material(
    color: color,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: () => onTab(filter),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, size: 21, color: _ink),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _template(CampaignTemplateModel template) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => onTemplate(template),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 118, child: _image(template.headerImageUrl)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.tagLabel.isEmpty
                        ? template.category
                        : template.tagLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    template.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Use template →',
                    style: const TextStyle(
                      color: _purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _image(String path) {
    final fallback = Container(
      color: const Color(0xFFEAE5FA),
      child: const Center(
        child: Icon(Icons.campaign_outlined, color: _purple, size: 40),
      ),
    );
    if (path.isEmpty) return fallback;
    if (path.startsWith('assets/'))
      return Image.asset(
        path,
        fit: BoxFit.cover,
        cacheWidth: 600,
        errorBuilder: (_, error, stack) => fallback,
      );
    return Image.network(
      ApiEndpoints.resolveMediaUrl(path),
      fit: BoxFit.cover,
      cacheWidth: 600,
      errorBuilder: (_, error, stack) => fallback,
    );
  }

  Widget _campaign(CampaignModel campaign) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: () => onCampaign(campaign),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              campaign.name,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  campaign.status.toUpperCase(),
                  style: const TextStyle(
                    color: _purple,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${campaign.audience.recipientCount} recipients',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                Text(
                  '${campaign.stats.messagesSent} sent',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _empty() => _surface(
    Column(
      children: [
        const Icon(Icons.campaign_outlined, size: 32, color: _muted),
        const SizedBox(height: 12),
        Text(
          loading
              ? 'Loading your campaigns…'
              : tab == 'Explore Campaigns'
              ? 'No matching templates'
              : 'No ${tab.toLowerCase()} campaigns',
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Try another filter or create a new campaign.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    ),
  );
}
