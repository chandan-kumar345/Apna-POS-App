import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';

class CampaignDetailsMonitoringView extends StatefulWidget {
  final CampaignModel campaign;
  final VoidCallback onBack;

  const CampaignDetailsMonitoringView({
    super.key,
    required this.campaign,
    required this.onBack,
  });

  @override
  State<CampaignDetailsMonitoringView> createState() => _CampaignDetailsMonitoringViewState();
}

class _CampaignDetailsMonitoringViewState extends State<CampaignDetailsMonitoringView> {
  final CampaignService _campaignService = CampaignService();
  late CampaignModel _currentCampaign;
  String _activeTab = 'Overview';
  bool _isPausing = false;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentCampaign = widget.campaign;
    _refreshCampaign();

    // Auto-poll to catch live delivery updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final hasPending = _currentCampaign.audience.recipients.any((r) => r.status == 'pending');
      if (_currentCampaign.isRunning || hasPending) {
        _refreshCampaign();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCampaign() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final fresh = await _campaignService.fetchCampaignById(_currentCampaign.id);
      if (mounted && fresh != null) {
        setState(() {
          _currentCampaign = fresh;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _togglePause() async {
    setState(() => _isPausing = true);
    if (_currentCampaign.isRunning) {
      await _campaignService.pauseCampaign(_currentCampaign.id);
    } else {
      await _campaignService.resumeCampaign(_currentCampaign.id);
    }
    final refreshed = await _campaignService.fetchCampaignById(_currentCampaign.id);
    if (mounted) {
      setState(() {
        if (refreshed != null) _currentCampaign = refreshed;
        _isPausing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header Bar
          _buildHeaderBar(),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subheader Navigation Tabs
                      _buildTabs(),
                      const SizedBox(height: 20),

                      // 4 Metric Stats Cards: Sent, Delivered, Open (Read), Failed
                      _buildStatsRow(),
                      const SizedBox(height: 20),

                      // Progress Bar & Meta Banner
                      _buildProgressCard(),
                      const SizedBox(height: 20),

                      // Recipients Breakdown Table
                      _buildRecipientsBreakdownCard(),
                      const SizedBox(height: 20),

                      // Cost & Wallet + Delivery Chart Cards Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _buildCostWalletCard()),
                          const SizedBox(width: 20),
                          Expanded(flex: 6, child: _buildDeliveryChartCard()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),
          Text(
            _currentCampaign.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _currentCampaign.isCompleted
                  ? const Color(0xFFDCFCE7)
                  : (_currentCampaign.isRunning ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 3.5,
                  backgroundColor: _currentCampaign.isCompleted
                      ? const Color(0xFF16A34A)
                      : (_currentCampaign.isRunning ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
                ),
                const SizedBox(width: 5),
                Text(
                  _currentCampaign.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _currentCampaign.isCompleted
                        ? const Color(0xFF15803D)
                        : (_currentCampaign.isRunning ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _currentCampaign.campaignId,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          // Refresh Button
          IconButton(
            onPressed: _refreshCampaign,
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Refresh Delivery Status',
          ),
          const SizedBox(width: 6),
          // Pause / Resume Button
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: _isPausing ? null : _togglePause,
              icon: Icon(
                _currentCampaign.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 16,
              ),
              label: Text(_currentCampaign.isRunning ? 'Pause' : 'Resume',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF95B1C),
                side: const BorderSide(color: Color(0xFFF95B1C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
            tooltip: 'Options',
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (action) async {
              if (action == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Delete Campaign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    content: Text('Are you sure you want to delete "${_currentCampaign.name}"? This action cannot be undone.', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await _campaignService.deleteCampaign(_currentCampaign.id);
                  widget.onBack();
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Text('Delete Campaign', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Overview', 'Delivery Report', 'Customer List', 'Message Preview'];

    return Row(
      children: tabs.map((t) {
        final isSelected = _activeTab == t;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () => setState(() => _activeTab = t),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                t,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsRow() {
    final stats = _currentCampaign.stats;
    final openRate = stats.messagesSent > 0
        ? ((stats.read / stats.messagesSent) * 100).toStringAsFixed(1)
        : (stats.read > 0 ? '70.0' : '0.0');
    final failRate = stats.totalRecipients > 0
        ? ((stats.failed / stats.totalRecipients) * 100).toStringAsFixed(1)
        : '0.0';

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Messages Sent',
            '${stats.messagesSent}',
            Icons.send_rounded,
            const Color(0xFF6366F1),
            const Color(0xFFEEF2FF),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricCard(
            'Delivered',
            '${stats.delivered}',
            Icons.done_all_rounded,
            const Color(0xFF10B981),
            const Color(0xFFECFDF5),
            badge: '${stats.deliveryRate > 0 ? stats.deliveryRate.toStringAsFixed(1) : (stats.messagesSent > 0 ? "100.0" : "0.0")}%',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricCard(
            'Open (Read)',
            '${stats.read}',
            Icons.mark_email_read_rounded,
            const Color(0xFF0EA5E9),
            const Color(0xFFF0F9FF),
            badge: '$openRate%',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricCard(
            'Failed',
            '${stats.failed}',
            Icons.error_outline_rounded,
            const Color(0xFFEF4444),
            const Color(0xFFFEF2F2),
            badge: '$failRate%',
            isNegative: stats.failed > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientsBreakdownCard() {
    final recipients = _currentCampaign.audience.recipients;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFFF95B1C)),
                const SizedBox(width: 8),
                const Text(
                  'Recipient Delivery & Read Status',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${recipients.isNotEmpty ? recipients.length : _currentCampaign.stats.totalRecipients} Recipient(s)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          if (recipients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Audience: ${_currentCampaign.audience.groupName} (${_currentCampaign.stats.totalRecipients > 0 ? _currentCampaign.stats.totalRecipients : 1} contacts queued).',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Customer / Phone', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                  Expanded(flex: 2, child: Text('Sent / Delivered Time', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                  Expanded(flex: 3, child: Text('Message ID / Note', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recipients.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, index) {
                final r = recipients[index];
                Color badgeBg = const Color(0xFFF1F5F9);
                Color badgeText = const Color(0xFF64748B);
                IconData badgeIcon = Icons.hourglass_top_rounded;
                String statusLabel = r.status.toUpperCase();

                if (r.status == 'read') {
                  badgeBg = const Color(0xFFE0F2FE);
                  badgeText = const Color(0xFF0284C7);
                  badgeIcon = Icons.visibility_rounded;
                  statusLabel = 'OPEN (READ)';
                } else if (r.status == 'delivered') {
                  badgeBg = const Color(0xFFDCFCE7);
                  badgeText = const Color(0xFF16A34A);
                  badgeIcon = Icons.done_all_rounded;
                  statusLabel = 'DELIVERED';
                } else if (r.status == 'sent') {
                  badgeBg = const Color(0xFFEEF2FF);
                  badgeText = const Color(0xFF6366F1);
                  badgeIcon = Icons.done_rounded;
                  statusLabel = 'SENT';
                } else if (r.status == 'failed') {
                  badgeBg = const Color(0xFFFEE2E2);
                  badgeText = const Color(0xFFDC2626);
                  badgeIcon = Icons.error_outline_rounded;
                  statusLabel = 'FAILED';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                              child: const Center(
                                child: Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.phone,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    r.name.isNotEmpty ? r.name : 'Customer',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 12, color: badgeText),
                                const SizedBox(width: 4),
                                Text(statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: badgeText)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          r.deliveredAt != null
                              ? '${r.deliveredAt!.hour}:${r.deliveredAt!.minute.toString().padLeft(2, '0')} - Delivered'
                              : (r.sentAt != null ? '${r.sentAt!.hour}:${r.sentAt!.minute.toString().padLeft(2, '0')} - Sent' : 'Queued'),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          r.error != null && r.error!.isNotEmpty
                              ? r.error!
                              : (r.messageId ?? 'Processed via WhatsApp Cloud API'),
                          style: TextStyle(
                            fontSize: 11,
                            color: r.error != null ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color iconColor, Color bgColor, {String? badge, bool isNegative = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isNegative ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isNegative ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final completion = _currentCampaign.stats.completionRate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 3, backgroundColor: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          _currentCampaign.isRunning ? 'Running' : 'Scheduled',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Scheduled Time: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text(
                    _currentCampaign.estimatedSendingTime.isNotEmpty
                        ? _currentCampaign.estimatedSendingTime
                        : '25 Oct 2026, 11:00 AM',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Text(
                'Estimated Completion: ${completion.toStringAsFixed(0)}% Complete',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (completion / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostWalletCard() {
    final cost = _currentCampaign.cost;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost & Wallet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          _buildCostDetail('Total', '₹${cost.totalAmount.toStringAsFixed(2)}'),
          _buildCostDetail('Spent So Far', '₹${cost.spentSoFar.toStringAsFixed(2)}'),
          _buildCostDetail('Remaining', '₹${cost.remaining.toStringAsFixed(2)}'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                foregroundColor: const Color(0xFF334155),
              ),
              child: const Text('View Wallet', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildDeliveryChartCard() {
    final timeline = _currentCampaign.deliveryTimeline;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery Chart', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Row(
                children: [
                  _buildLegendItem('Sent', const Color(0xFF2563EB)),
                  const SizedBox(width: 14),
                  _buildLegendItem('Delivered', const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _DeliveryChartPainter(points: timeline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _DeliveryChartPainter extends CustomPainter {
  final List<DeliveryTimelinePoint> points;

  _DeliveryChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final sentPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final deliveredPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    for (int i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final int maxVal = 320;
    final double stepX = size.width / (points.length - 1);

    final Path sentPath = Path();
    final Path deliveredPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final ySent = size.height - (points[i].sent / maxVal) * size.height;
      final yDelivered = size.height - (points[i].delivered / maxVal) * size.height;

      if (i == 0) {
        sentPath.moveTo(x, ySent);
        deliveredPath.moveTo(x, yDelivered);
      } else {
        sentPath.lineTo(x, ySent);
        deliveredPath.lineTo(x, yDelivered);
      }

      // Draw point dots
      canvas.drawCircle(Offset(x, ySent), 3, Paint()..color = const Color(0xFF2563EB));
      canvas.drawCircle(Offset(x, yDelivered), 3, Paint()..color = const Color(0xFF10B981));
    }

    canvas.drawPath(sentPath, sentPaint);
    canvas.drawPath(deliveredPath, deliveredPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
