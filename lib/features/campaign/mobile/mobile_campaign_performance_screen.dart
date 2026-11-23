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

    final rawImageUrl = (template['headerMediaUrl'] ??
            template['mediaUrl'] ??
            r['bannerImageUrl'] ??
            _c['headerMediaUrl'] ??
            _c['bannerImageUrl'] ??
            _c['imageUrl'] ??
            '')
        .toString()
        .trim();

    // Ensure image is displayed: if no remote URL is present, use the bundled campaign banner
    final imageUrl = rawImageUrl.isNotEmpty
        ? rawImageUrl
        : 'assets/images/tpl_food_bogo_pizza.png';

    final sentAt = DateTime.tryParse(
      _c['schedule']?['sentAt']?.toString() ??
          _c['schedule']?['scheduledAt']?.toString() ??
          _c['createdAt']?.toString() ??
          '',
    );
    final timeStr = sentAt != null
        ? DateFormat('hh:mm a').format(indiaClock(sentAt))
        : '04:21 PM';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),

              // Header Row: 3D WhatsApp Icon, Title & Subtitle, Close Button
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE8F5E9), Color(0xFFDCFCE7)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/whatsapp_logo.png',
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFF25D366),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campaign Preview',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F1E36),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'See how your message will appear on WhatsApp',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 19,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // WhatsApp Smartphone Mockup with message and image
              Center(
                child: WhatsAppPhonePreview(
                  businessName: widget.options?.business ?? 'Pizza 47',
                  messageBody: body.toString().replaceAll('{{name}}', 'John'),
                  headerText: template['headerText'],
                  footerText:
                      template['footerText'] ?? 'Terms & Conditions apply',
                  imageUrl: imageUrl,
                  time: timeStr,
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
    return ColoredBox(
      color: const Color(0xFFEDF4FA),
      child: CampaignShell(
        header: _buildHeader(),
        body: _buildBody(),
        footer: _buildFooter(),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Text(
            _headerTitle,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadFullCampaign,
      color: const Color(0xFF0077B6),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        children: [
          // Top Campaign Card
          _buildCampaignSummaryCard(),
          const SizedBox(height: 10),

          // Segmented Tabs: [Overview] [Customers] [Details]
          _buildTabPills(),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF0077B6),
                backgroundColor: Color(0xFFE0F2FE),
              ),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _loadError!,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: muted,
                ),
              ),
            ),

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
        ? DateFormat('d MMM yyyy · hh:mm a').format(indiaClock(sentAt))
        : '20 Nov 2026 · 06:00 PM';

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: _buildThumbnailImage(imageUrl),
            ),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFDCFCE7)
                            : (rawStatus == 'scheduled'
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFFFE3CA)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCompleted) ...[
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 11.5,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            isCompleted
                                ? 'Completed'
                                : (rawStatus == 'scheduled'
                                    ? 'Scheduled'
                                    : 'Active'),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? const Color(0xFF15803D)
                                  : (rawStatus == 'scheduled'
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFFC05621)),
                            ),
                          ),
                        ],
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
                        width: 13,
                        height: 13,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.chat_bubble,
                          color: Color(0xFF25D366),
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'WhatsApp · $categoryLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF64748B),
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Sent $sentStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    expiryStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
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
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTabPills() {
    return Row(
      children: [
        _tabPillItem(
          0,
          'Overview',
          Icons.bar_chart_rounded,
          Icons.analytics_outlined,
        ),
        const SizedBox(width: 6),
        _tabPillItem(
          1,
          'Customers',
          Icons.people_alt_rounded,
          Icons.people_alt_outlined,
        ),
        const SizedBox(width: 6),
        _tabPillItem(
          2,
          'Details',
          Icons.description_rounded,
          Icons.description_outlined,
        ),
      ],
    );
  }

  Widget _tabPillItem(
    int index,
    String label,
    IconData activeIcon,
    IconData inactiveIcon,
  ) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF0077B6).withValues(alpha: 0.35)
                      : const Color(0xFF0B2545).withValues(alpha: 0.05),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  size: 14,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF0F1E36),
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
            child: _claymorphicStatCard(
              label: 'Recipients',
              value: fmt.format(stats.recipients),
              icon: Icons.people_alt_outlined,
              iconGradient: const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
              iconColor: const Color(0xFF0284C7),
              waveColor: const Color(0xFFE0F2FE),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _claymorphicStatCard(
              label: 'Delivered',
              value: fmt.format(stats.delivered),
              icon: Icons.check_circle_outline_rounded,
              iconGradient: const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
              iconColor: const Color(0xFF16A34A),
              waveColor: const Color(0xFFDCFCE7),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _claymorphicStatCard(
              label: 'Read',
              value: fmt.format(stats.read),
              icon: Icons.visibility_outlined,
              iconGradient: const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
              iconColor: const Color(0xFF7C3AED),
              waveColor: const Color(0xFFEDE9FE),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _claymorphicStatCard(
              label: 'Failed',
              value: fmt.format(stats.failed),
              icon: Icons.cancel_outlined,
              iconGradient: const [Color(0xFFFEE2E2), Color(0xFFFECACA)],
              iconColor: const Color(0xFFDC2626),
              waveColor: const Color(0xFFFEE2E2),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Delivery Results Card
      _buildDeliveryResultsCard(stats),
      const SizedBox(height: 12),

      // Coupon Performance Cards
      Row(
        children: [
          Expanded(
            child: _couponStatCard(
              label: 'Coupon orders',
              value: _metricsLoaded ? fmt.format(stats.couponOrders) : '—',
              icon: Icons.shopping_cart_outlined,
              gradient: const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
              iconColor: const Color(0xFF16A34A),
              waveColor: const Color(0xFFDCFCE7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _couponStatCard(
              label: 'Coupon revenue',
              value: _metricsLoaded
                  ? '₹${NumberFormat('#,##,##0.##', 'en_IN').format(stats.couponRevenue)}'
                  : '—',
              icon: Icons.confirmation_number_outlined,
              gradient: const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
              iconColor: const Color(0xFF7C3AED),
              waveColor: const Color(0xFFEDE9FE),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // View customer delivery status link button
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => setState(() => _selectedTab = 1),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
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
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  color: Color(0xFF0077B6),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'View customer delivery status',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F1E36),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF64748B),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _claymorphicStatCard({
    required String label,
    required String value,
    required IconData icon,
    required List<Color> iconGradient,
    required Color iconColor,
    required Color waveColor,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: waveColor.withValues(alpha: 0.35),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: iconGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
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
                        fontSize: 10.5,
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
                          fontSize: 19,
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
    );
  }

  Widget _couponStatCard({
    required String label,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    required Color iconColor,
    required Color waveColor,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            bottom: -18,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: waveColor.withValues(alpha: 0.35),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 7),
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
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F1E36),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryResultsCard(_CampaignStatsData stats) {
    final fmt = NumberFormat.decimalPattern('en_IN');
    final deliveryRateStr =
        '${stats.deliveryRate.toStringAsFixed(1)}% delivery rate';

    // Segment ratios for the progress bar
    final total = stats.recipients > 0 ? stats.recipients : 1;
    final readFlex = (stats.read * 1000 / total).round();
    final deliveredNotReadFlex =
        (stats.deliveredNotRead * 1000 / total).round();
    final failedFlex = (stats.failed * 1000 / total).round();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Flexible & Wrapping protection
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Delivery results',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1E36),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          deliveryRateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 10.5,
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 11.5,
                        color: Color(0xFF15803D),
                      ),
                    ],
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
              child: (readFlex == 0 && deliveredNotReadFlex == 0 && failedFlex == 0)
                  ? Container(color: const Color(0xFFE2E8F0))
                  : Row(
                      children: [
                        if (readFlex > 0)
                          Expanded(
                            flex: readFlex,
                            child: Container(color: const Color(0xFF8B5CF6)),
                          ),
                        if (deliveredNotReadFlex > 0)
                          Expanded(
                            flex: deliveredNotReadFlex,
                            child: Container(color: const Color(0xFF00B4D8)),
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
          const SizedBox(height: 10),

          // Legend list rows
          _deliveryRowItem(
            color: const Color(0xFF8B5CF6),
            label: 'Read',
            count: fmt.format(stats.read),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Divider(height: 1, thickness: 0.6, color: Color(0xFFF1F5F9)),
          ),
          _deliveryRowItem(
            color: const Color(0xFF00B4D8),
            label: 'Delivered, not read',
            count: fmt.format(stats.deliveredNotRead),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Divider(height: 1, thickness: 0.6, color: Color(0xFFF1F5F9)),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11.5,
                color: Color(0xFF0F1E36),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F1E36),
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
          onChanged: (val) => setState(() => _customerSearch = val.trim()),
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: Color(0xFF0F1E36),
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            hintText: 'Search customer name or phone...',
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
      const SizedBox(height: 10),

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
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _customerFilter = filterKey),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: _customerFilter == filterKey
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                            )
                          : null,
                      color: _customerFilter == filterKey ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _customerFilter == filterKey
                              ? const Color(0xFF0077B6).withValues(alpha: 0.35)
                              : const Color(0xFF0B2545).withValues(alpha: 0.05),
                          blurRadius: _customerFilter == filterKey ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: _customerFilter == filterKey
                            ? Colors.white
                            : const Color(0xFF0F1E36),
                        fontWeight: _customerFilter == filterKey
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 14),

      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Text(
              'No matching customers found',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13.5,
                color: muted,
              ),
            ),
          ),
        )
      else
        for (final item in filtered) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Text(
                    (item['name'] as String? ?? 'C').isNotEmpty
                        ? (item['name'] as String)[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Customer',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1E36),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['phone'] ?? '',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
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
        ? DateFormat('d MMM · hh:mm a').format(indiaClock(sentAt))
        : '20 Nov · 06:00 PM';

    final completedAt = sentAt != null
        ? sentAt.add(const Duration(minutes: 4))
        : DateTime.now();
    final completedStr =
        DateFormat('d MMM · hh:mm a').format(indiaClock(completedAt));

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
        ? DateFormat('d MMM yyyy · hh:mm a').format(indiaClock(expiryAt))
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE9FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Campaign information',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1E36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                  Text(
                    'WhatsApp',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F1E36),
                    ),
                  ),
                ],
              ),
            ),
            _infoRow(
              'Category',
              Text(
                categoryLabel,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Audience',
              Text(
                audienceName,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Recipients',
              Text(
                NumberFormat.decimalPattern('en_IN').format(recipientsCount),
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Sent on',
              Text(
                sentStr,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Completed at',
              Text(
                completedStr,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
              isLast: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Card 2: Reward Details
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.confirmation_number_outlined,
                    color: Color(0xFF0284C7),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Reward details',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1E36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow(
              'Order type',
              Text(
                orders,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Reward',
              Text(
                rewardLabel,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Minimum order',
              Text(
                minOrder,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Maximum discount',
              Text(
                maxDiscount,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
            _infoRow(
              'Coupon code',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    couponCode,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0077B6),
                    ),
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
                      child: Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: Color(0xFF0F1E36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _infoRow(
              'Expires',
              Text(
                expiryFormatted,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
              isLast: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Card 3: Preview snippet
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _infoRow(String label, Widget value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: value,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER (Sticky Actions)
  // ---------------------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary button: + Send to new customers
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _audienceDialog(false),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Send to new customers',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14.5,
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
          const SizedBox(height: 8),

          // Secondary button row: Resend & Preview
          Row(
            children: [
              Expanded(
                child: _claymorphicButton(
                  label: 'Resend',
                  icon: Icons.refresh_rounded,
                  onTap: () => _audienceDialog(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _claymorphicButton(
                  label: 'Preview',
                  icon: Icons.visibility_outlined,
                  onTap: _onPreview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _claymorphicButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2545).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0F1E36)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F1E36),
                ),
              ),
            ],
          ),
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
