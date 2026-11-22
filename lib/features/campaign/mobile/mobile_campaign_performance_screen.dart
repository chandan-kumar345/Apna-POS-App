import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'campaign_audience_dialog.dart';

import 'whatsapp_phone_preview.dart';

import 'campaign_style.dart';
import 'mobile_campaign_data.dart';

class MobileCampaignPerformanceScreen extends StatefulWidget {
  final CampaignJson campaign;
  final CampaignOptions? options;
  final MobileCampaignApi? api;
  final VoidCallback? onRefreshDashboard;
  final int initialTab;

  const MobileCampaignPerformanceScreen({
    super.key,
    required this.campaign,
    this.options,
    this.api,
    this.onRefreshDashboard,
    this.initialTab = 0,
  });

  @override
  State<MobileCampaignPerformanceScreen> createState() =>
      _MobileCampaignPerformanceScreenState();
}

class _MobileCampaignPerformanceScreenState
    extends State<MobileCampaignPerformanceScreen> {
  late final MobileCampaignApi _api = widget.api ?? MobileCampaignApi();


  late int _selectedTab;
  late CampaignJson _c;
  bool _metricsLoaded = false;
  String? _loadError;
  bool _loading = false;
  String _customerSearch = '';
  String _customerFilter = 'all';

  // In-memory customer list for the Customers tab
  List<Map<String, dynamic>> _recipients = [];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _c = Map<String, dynamic>.from(widget.campaign);
    _populateRecipients();
    _loadFullCampaign();
  }

  Future<void> _loadFullCampaign() async {
    final campaignId = (_c['id'] ?? _c['_id'] ?? '').toString();
    if (campaignId.isEmpty) return;

    setState(() { _loading = true; _loadError = null; });
    try {
      final details = await _api.performance(campaignId);
      if (!mounted) return;
      setState(() {
        _c = details;
        _populateRecipients();
        _metricsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not refresh performance. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateRecipients() {
    _recipients = [for (final r in _c['audience']?['recipients'] ?? []) Map<String, dynamic>.from(r)];
  }

  _CampaignStatsData _getStats() {
    final rawStats = _c['stats'] ?? {};
    final audience = _c['audience'] ?? {};

    int recipients = rawStats['totalRecipients'] ??
        audience['recipientCount'] ??
        audience['count'] ??
        0;
    int delivered = rawStats['delivered'] ?? 0;
    int read = rawStats['read'] ?? 0;
    int failed = rawStats['failed'] ?? 0;

    // Safety checks
    if (delivered > recipients) delivered = recipients;
    if (read > delivered) read = delivered;
    int deliveredNotRead = delivered - read;
    if (deliveredNotRead < 0) deliveredNotRead = 0;

    double deliveryRate = (rawStats['deliveryRate'] as num?)?.toDouble() ??
        (recipients > 0 ? (delivered / recipients) * 100 : 0.0);

    final couponOrders = (rawStats['couponOrders'] as num?)?.toInt() ?? 0;
    final couponRevenue = (rawStats['couponRevenue'] as num?)?.toDouble() ?? 0;

    return _CampaignStatsData(
      recipients: recipients,
      delivered: delivered,
      read: read,
      failed: failed,
      deliveredNotRead: deliveredNotRead,
      deliveryRate: deliveryRate,
      couponOrders: couponOrders,
      couponRevenue: couponRevenue,
    );
  }

  String get _headerTitle {
    switch (_selectedTab) {
      case 2:
        return 'Campaign details';
      case 1:
        return 'Campaign performance';
      default:
        return 'Campaign performance';
    }
  }

  Future<void> _audienceDialog(bool resend) async {
    final queued = await showDialog<bool>(
      context: context,
      builder: (_) => CampaignAudienceDialog(api: _api, campaign: _c, options: widget.options, resend: resend),
    );
    if (!mounted || queued != true) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign queued for sending')));
    widget.onRefreshDashboard?.call();
    await _loadFullCampaign();
  }

  void _onPreview() {
    final template = _c['template'] ?? {};
    final r = _c['rewardDetails'] ?? {};
    final coupon = _c['couponSettings']?['couponCode'] ?? 'WEEKEND20';
    final body = template['body'] ??
        r['description'] ??
        'Hi {{name}} 🍕\nEnjoy 20% OFF your next order with code $coupon.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC4D5E2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Image.asset(
                    'assets/images/whatsapp_logo.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.chat_bubble,
                      color: Color(0xFF25D366),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WhatsApp Message Preview',
                    style: campaignText(16, weight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: WhatsAppPhonePreview(
                  businessName: widget.options?.business ?? 'Pizza 47',
                  messageBody: body.toString().replaceAll('{{name}}', 'John'),
                  headerText: template['headerText'] ?? _c['name'],
                  footerText: template['footerText'] ?? 'Terms & Conditions apply',
                  buttons: [
                    if (coupon.toString().isNotEmpty) 'Copy code: $coupon',
                    'Order Now',
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CampaignShell(
      header: _buildHeader(),
      body: _buildBody(),
      footer: _buildFooter(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Text(
            _headerTitle,
            style: campaignText(20, color: Colors.white, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadFullCampaign,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        children: [
          // Top Campaign Card
          _buildCampaignSummaryCard(),
          const SizedBox(height: 12),

          // Segmented Tabs: [Overview] [Customers] [Details]
          _buildTabPills(),
          const SizedBox(height: 14),

          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_loadError != null) Text(_loadError!, style: campaignText(13, color: muted)),

          // Tab content based on selected tab
          if (_selectedTab == 0) ..._buildOverviewTab(),
          if (_selectedTab == 1) ..._buildCustomersTab(),
          if (_selectedTab == 2) ..._buildDetailsTab(),
        ],
      ),
    );
  }

  Widget _buildCampaignSummaryCard() {
    final name = _c['name'] ?? 'Weekend Pizza Offer';
    final imageUrl = _c['template']?['headerMediaUrl'] ??
        _c['rewardDetails']?['bannerImageUrl'] ??
        '';

    final category = _c['template']?['category'] ??
        _c['category'] ??
        _c['type'] ??
        'MARKETING';
    final categoryLabel = campaignCategories[category] ?? 'Marketing';

    // Dates
    final sentAt = DateTime.tryParse(
      _c['schedule']?['sentAt']?.toString() ??
          _c['schedule']?['scheduledAt']?.toString() ??
          _c['createdAt']?.toString() ??
          '',
    );
    final sentStr = sentAt != null
        ? DateFormat('d MMM yyyy · h:mm a').format(indiaClock(sentAt))
        : '20 Nov 2026 · 6:00 PM';

    final expiryAt = DateTime.tryParse(
      _c['couponSettings']?['expiryDate']?.toString() ?? '',
    );
    final expiryStr = expiryAt != null
        ? 'Coupon active until ${DateFormat('d MMM').format(indiaClock(expiryAt))}'
        : 'Coupon active until 30 Nov';

    final rawStatus = _c['status'] ?? 'completed';
    final isCompleted = rawStatus == 'completed' || rawStatus == 'sent';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: campaignCard(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 54,
              height: 54,
              child: _buildThumbnailImage(imageUrl),
            ),
          ),
          const SizedBox(width: 12),

          // Content
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
                        style: campaignText(16, weight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFFE3CA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Completed'
                            : (rawStatus == 'scheduled' ? 'Scheduled' : 'Active'),
                        style: campaignText(
                          11,
                          color: isCompleted
                              ? const Color(0xFF15803D)
                              : const Color(0xFFC05621),
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (_selectedTab != 2) ...[
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/whatsapp_logo.png',
                        width: 14,
                        height: 14,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.chat_bubble,
                          color: Color(0xFF25D366),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'WhatsApp · $categoryLabel',
                        style: campaignText(12, color: muted, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: muted,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sent $sentStr',
                        style: campaignText(12, color: muted, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    expiryStr,
                    style: campaignText(12, color: muted, weight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailImage(String url) {
    if (url.isNotEmpty && url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackThumbnail(),
      );
    }
    return _fallbackThumbnail();
  }

  Widget _fallbackThumbnail() {
    return Image.asset(
      'assets/images/tpl_food_bogo_pizza.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFFFECE0),
        child: const Icon(
          Icons.local_pizza_rounded,
          color: Color(0xFFE65100),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildTabPills() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF3F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _tabPillItem(0, 'Overview'),
          _tabPillItem(1, 'Customers'),
          _tabPillItem(2, 'Details'),
        ],
      ),
    );
  }

  Widget _tabPillItem(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
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
          child: Text(
            label,
            style: campaignText(
              13,
              color: isSelected ? Colors.white : ink,
              weight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: OVERVIEW
  // ---------------------------------------------------------------------------
  List<Widget> _buildOverviewTab() {
    final stats = _getStats();
    final fmt = NumberFormat.decimalPattern('en_IN');

    return [
      // 2x2 Metric Cards Grid
      Row(
        children: [
          Expanded(
            child: _metricCard(
              label: 'Recipients',
              value: fmt.format(stats.recipients),
              icon: Icons.people_alt_outlined,
              bgColor: const Color(0xFFE0F2FE),
              borderColor: const Color(0xFFBAE6FD),
              iconColor: const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricCard(
              label: 'Delivered',
              value: fmt.format(stats.delivered),
              icon: Icons.check_circle_outline_rounded,
              bgColor: const Color(0xFFDCFCE7),
              borderColor: const Color(0xFFBBF7D0),
              iconColor: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _metricCard(
              label: 'Read',
              value: fmt.format(stats.read),
              icon: Icons.visibility_outlined,
              bgColor: const Color(0xFFEDE9FE),
              borderColor: const Color(0xFFDDD6FE),
              iconColor: const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricCard(
              label: 'Failed',
              value: fmt.format(stats.failed),
              icon: Icons.cancel_outlined,
              bgColor: const Color(0xFFFEE2E2),
              borderColor: const Color(0xFFFECACA),
              iconColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // Delivery Results Card
      _buildDeliveryResultsCard(stats),
      const SizedBox(height: 14),

      // Coupon Performance Cards
      Row(
        children: [
          Expanded(
            child: _smallStatCard(
              label: 'Coupon orders',
              value: _metricsLoaded ? fmt.format(stats.couponOrders) : '—',
              icon: Icons.shopping_cart_outlined,
              bgColor: const Color(0xFFE8FAF0),
              iconColor: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _smallStatCard(
              label: 'Coupon revenue',
              value: _metricsLoaded ? '₹${NumberFormat('#,##,##0.##', 'en_IN').format(stats.couponRevenue)}' : '—',
              icon: Icons.payments_outlined,
              bgColor: const Color(0xFFF4EDFE),
              iconColor: const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // View customer delivery status link button
      InkWell(
        onTap: () => setState(() => _selectedTab = 1),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: campaignCard(radius: 14),
          child: Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: teal, size: 20),
              const SizedBox(width: 10),
              Text(
                'View customer delivery status',
                style: campaignText(13.5, weight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded, color: ink, size: 18),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [studioShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: campaignText(12, color: muted, weight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: campaignText(22, weight: FontWeight.w800, color: ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryResultsCard(_CampaignStatsData stats) {
    final fmt = NumberFormat.decimalPattern('en_IN');
    final deliveryRateStr = '${stats.deliveryRate.toStringAsFixed(1)}% delivery rate';

    // Segment ratios for the progress bar
    final total = stats.recipients > 0 ? stats.recipients : 1;
    final readFlex = (stats.read * 1000 / total).round();
    final deliveredNotReadFlex = (stats.deliveredNotRead * 1000 / total).round();
    final failedFlex = (stats.failed * 1000 / total).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: campaignCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Delivery results',
                style: campaignText(15, weight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  deliveryRateStr,
                  style: campaignText(
                    11.5,
                    color: const Color(0xFF15803D),
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-color segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  if (readFlex > 0)
                    Expanded(
                      flex: readFlex,
                      child: Container(color: const Color(0xFF8B5CF6)),
                    ),
                  if (deliveredNotReadFlex > 0)
                    Expanded(
                      flex: deliveredNotReadFlex,
                      child: Container(color: const Color(0xFF38BDF8)),
                    ),
                  if (failedFlex > 0)
                    Expanded(
                      flex: failedFlex,
                      child: Container(color: const Color(0xFFF87171)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Legend list rows
          _deliveryRowItem(
            color: const Color(0xFF8B5CF6),
            label: 'Read',
            count: fmt.format(stats.read),
          ),
          const SizedBox(height: 8),
          _deliveryRowItem(
            color: const Color(0xFF38BDF8),
            label: 'Delivered, not read',
            count: fmt.format(stats.deliveredNotRead),
          ),
          const SizedBox(height: 8),
          _deliveryRowItem(
            color: const Color(0xFFF87171),
            label: 'Failed to deliver',
            count: fmt.format(stats.failed),
          ),
        ],
      ),
    );
  }

  Widget _deliveryRowItem({
    required Color color,
    required String label,
    required String count,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: campaignText(13, color: ink, weight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          count,
          style: campaignText(13.5, weight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _smallStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
        boxShadow: const [studioShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: CUSTOMERS
  // ---------------------------------------------------------------------------
  List<Widget> _buildCustomersTab() {
    final filtered = _recipients.where((r) {
      final matchesSearch = _customerSearch.isEmpty ||
          r['name'].toString().toLowerCase().contains(_customerSearch.toLowerCase()) ||
          r['phone'].toString().contains(_customerSearch);

      if (!matchesSearch) return false;
      if (_customerFilter == 'all') return true;
      return r['status'] == _customerFilter;
    }).toList();

    return [
      // Search Bar
      TextField(
        onChanged: (val) => setState(() => _customerSearch = val.trim()),
        style: campaignText(13),
        decoration: campaignInput(hint: 'Search customer name or phone').copyWith(
          prefixIcon: const Icon(Icons.search_rounded, color: ink, size: 19),
        ),
      ),
      const SizedBox(height: 8),

      // Status Filter Pills
      Row(
        children: [
          for (final (filterKey, label) in const [
            ('all', 'All'),
            ('read', 'Read'),
            ('delivered', 'Delivered'),
            ('failed', 'Failed'),
          ]) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                selected: _customerFilter == filterKey,
                onSelected: (sel) {
                  if (sel) setState(() => _customerFilter = filterKey);
                },
                selectedColor: teal,
                labelStyle: campaignText(
                  11.5,
                  color: _customerFilter == filterKey ? Colors.white : ink,
                  weight: _customerFilter == filterKey
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _customerFilter == filterKey
                        ? teal
                        : borderBlue.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 10),

      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Text(
              'No matching customers found',
              style: campaignText(13, color: muted),
            ),
          ),
        )
      else
        for (final item in filtered) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: campaignCard(radius: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEDF2F7),
                  child: Text(
                    (item['name'] as String? ?? 'C').isNotEmpty
                        ? (item['name'] as String)[0].toUpperCase()
                        : 'C',
                    style: campaignText(14, weight: FontWeight.w700, color: teal),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Customer',
                        style: campaignText(14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['phone'] ?? '',
                        style: campaignText(12, color: muted),
                      ),
                    ],
                  ),
                ),
                _customerStatusChip(item['status']?.toString() ?? 'delivered'),
              ],
            ),
          ),
        ],
    ];
  }

  Widget _customerStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'read':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        label = 'Read';
        break;
      case 'delivered':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Delivered';
        break;
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Failed';
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        label = status[0].toUpperCase() + status.substring(1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: campaignText(11, color: fg, weight: FontWeight.w700),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: DETAILS
  // ---------------------------------------------------------------------------
  List<Widget> _buildDetailsTab() {
    final category = _c['template']?['category'] ??
        _c['category'] ??
        _c['type'] ??
        'MARKETING';
    final categoryLabel = campaignCategories[category] ?? 'Marketing';

    final audienceName = _c['audience']?['groupName'] ??
        _c['audience']?['name'] ??
        'Loyal customers';
    final recipientsCount = _getStats().recipients;

    final sentAt = DateTime.tryParse(
      _c['schedule']?['sentAt']?.toString() ??
          _c['schedule']?['scheduledAt']?.toString() ??
          _c['createdAt']?.toString() ??
          '',
    );
    final sentStr = sentAt != null
        ? DateFormat('d MMM · h:mm a').format(indiaClock(sentAt))
        : '20 Nov · 6:00 PM';

    final completedAt = sentAt != null
        ? sentAt.add(const Duration(minutes: 4))
        : DateTime.now();
    final completedStr =
        DateFormat('d MMM · h:mm a').format(indiaClock(completedAt));

    // Rewards
    final r = _c['rewardDetails'] ?? {};
    final orders = (_c['orderTypes'] as List? ?? ['takeaway', 'delivery'])
        .map((t) => campaignOrders[t] ?? t)
        .join(', ');

    final rewardType = r['rewardType']?.toString() ?? 'percentage';
    final discountAmount = campaignNumber(r['discountAmount']);
    String rewardLabel;
    if (rewardType == 'percentage' || rewardType == 'percent_discount') {
      rewardLabel = '${discountAmount.isEmpty ? '20' : discountAmount}% discount';
    } else if (rewardType == 'flat_discount' || rewardType == 'flat_cash') {
      rewardLabel = 'Flat ₹${discountAmount.isEmpty ? '100' : discountAmount} discount';
    } else if (rewardType == 'bogo') {
      rewardLabel = 'Buy 1, Get 1 Free';
    } else {
      rewardLabel = 'Special reward';
    }

    final minOrderVal = campaignNumber(r['minSpendAmount'] ?? r['minOrderAmount']);
    final minOrder = minOrderVal.isNotEmpty ? '₹$minOrderVal' : '₹499';

    final maxCapVal = campaignNumber(r['maxCashbackCap'] ?? r['maxDiscountAmount']);
    final maxDiscount = maxCapVal.isNotEmpty ? '₹$maxCapVal' : '₹150';

    final couponCode = _c['couponSettings']?['couponCode'] ?? 'WEEKEND20';

    final expiryAt = DateTime.tryParse(
      _c['couponSettings']?['expiryDate']?.toString() ?? '',
    );
    final expiryFormatted = expiryAt != null
        ? DateFormat('d MMM yyyy · h:mm a').format(indiaClock(expiryAt))
        : '30 Nov 2026 · 11:59 PM IST';

    final previewBody = _c['template']?['body'] ??
        r['description'] ??
        'Hi {{name}} 🍕\nEnjoy 20% OFF your next order.';

    final imageUrl = _c['template']?['headerMediaUrl'] ??
        _c['rewardDetails']?['bannerImageUrl'] ??
        '';

    return [
      // Card 1: Campaign Information
      Container(
        padding: const EdgeInsets.all(14),
        decoration: campaignCard(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE9FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Color(0xFF7C3AED),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Campaign information',
                  style: campaignText(15, weight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(
              'Channel',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/whatsapp_logo.png',
                    width: 14,
                    height: 14,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.chat_bubble,
                      color: Color(0xFF25D366),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('WhatsApp', style: campaignText(13, weight: FontWeight.w600)),
                ],
              ),
            ),
            _infoRow('Category', Text(categoryLabel, style: campaignText(13, weight: FontWeight.w600))),
            _infoRow('Audience', Text(audienceName, style: campaignText(13, weight: FontWeight.w600))),
            _infoRow(
              'Recipients',
              Text(
                NumberFormat.decimalPattern('en_IN').format(recipientsCount),
                style: campaignText(13, weight: FontWeight.w600),
              ),
            ),
            _infoRow('Sent on', Text(sentStr, style: campaignText(13, weight: FontWeight.w600))),
            _infoRow(
              'Completed at',
              Text(completedStr, style: campaignText(13, weight: FontWeight.w600)),
              isLast: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Card 2: Reward Details
      Container(
        padding: const EdgeInsets.all(14),
        decoration: campaignCard(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.confirmation_number_outlined,
                    color: Color(0xFF0284C7),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Reward details',
                  style: campaignText(15, weight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Order type', Text(orders, style: campaignText(13, weight: FontWeight.w600))),
            _infoRow('Reward', Text(rewardLabel, style: campaignText(13, weight: FontWeight.w600))),
            _infoRow('Minimum order', Text(minOrder, style: campaignText(13, weight: FontWeight.w600))),
            _infoRow('Maximum discount', Text(maxDiscount, style: campaignText(13, weight: FontWeight.w600))),
            _infoRow(
              'Coupon code',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    couponCode,
                    style: campaignText(13, weight: FontWeight.w800, color: teal),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: couponCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coupon code copied')),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.copy_rounded, size: 15, color: ink),
                    ),
                  ),
                ],
              ),
            ),
            _infoRow(
              'Expires',
              Text(expiryFormatted, style: campaignText(13, weight: FontWeight.w600)),
              isLast: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Card 3: Preview snippet
      Container(
        padding: const EdgeInsets.all(12),
        decoration: campaignCard(radius: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 46,
                child: _buildThumbnailImage(imageUrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                previewBody,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: campaignText(13, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _infoRow(String label, Widget value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: campaignText(13, color: muted, weight: FontWeight.w400)),
          value,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER (Sticky Actions)
  // ---------------------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      color: Colors.white.withValues(alpha: 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary button: + Send to new customers
          SizedBox(
            width: double.infinity,
            child: CampaignPrimary(
              'Send to new customers',
              icon: Icons.person_add_alt_1_outlined,
              onTap: () => _audienceDialog(false),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary button row: Resend & Preview
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  'Resend',
                  Icons.refresh_rounded,
                  () => _audienceDialog(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _secondaryButton(
                  'Preview',
                  Icons.visibility_outlined,
                  _onPreview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _secondaryButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderBlue),
          boxShadow: const [studioShadow],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: campaignText(13.5, weight: FontWeight.w700, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignStatsData {
  final int recipients;
  final int delivered;
  final int read;
  final int failed;
  final int deliveredNotRead;
  final double deliveryRate;
  final int couponOrders;
  final double couponRevenue;

  const _CampaignStatsData({
    required this.recipients,
    required this.delivered,
    required this.read,
    required this.failed,
    required this.deliveredNotRead,
    required this.deliveryRate,
    required this.couponOrders,
    required this.couponRevenue,
  });
}
