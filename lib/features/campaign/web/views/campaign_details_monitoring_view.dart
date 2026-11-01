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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // Header Bar
              _buildHeaderBar(isNarrow),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 12 : 24,
                    vertical: isNarrow ? 12 : 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subheader Navigation Tabs
                          _buildTabs(isNarrow),
                          SizedBox(height: isNarrow ? 12 : 20),

                          // 4 Metric Stats Cards: Sent, Delivered, Open (Read), Failed
                          _buildStatsRow(isNarrow),
                          SizedBox(height: isNarrow ? 12 : 20),

                          // Progress Bar & Meta Banner
                          _buildProgressCard(isNarrow),
                          SizedBox(height: isNarrow ? 12 : 20),

                          // Recipients Breakdown Table
                          _buildRecipientsBreakdownCard(isNarrow),
                          SizedBox(height: isNarrow ? 12 : 20),

                          // Cost & Wallet + Delivery Chart Cards
                          if (isNarrow) ...[
                            _buildCostWalletCard(isNarrow),
                            const SizedBox(height: 14),
                            _buildDeliveryChartCard(isNarrow),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 4, child: _buildCostWalletCard(false)),
                                const SizedBox(width: 20),
                                Expanded(flex: 6, child: _buildDeliveryChartCard(false)),
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
      },
    );
  }

  Widget _buildHeaderBar(bool isNarrow) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 24,
        vertical: isNarrow ? 10 : 16,
      ),
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
          SizedBox(width: isNarrow ? 8 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _currentCampaign.name,
                        style: TextStyle(
                          fontSize: isNarrow ? 14 : 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 10),
                      _buildStatusBadge(isCompact: false),
                      const SizedBox(width: 10),
                      Text(
                        _currentCampaign.campaignId,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
                if (isNarrow) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _buildStatusBadge(isCompact: true),
                      const SizedBox(width: 6),
                      Text(
                        _currentCampaign.campaignId,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Refresh Button
          IconButton(
            onPressed: _refreshCampaign,
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
            tooltip: 'Refresh Delivery Status',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          // Pause / Resume Button
          SizedBox(
            height: isNarrow ? 30 : 38,
            child: OutlinedButton.icon(
              onPressed: _isPausing ? null : _togglePause,
              icon: Icon(
                _currentCampaign.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: isNarrow ? 13 : 16,
              ),
              label: Text(
                _currentCampaign.isRunning ? 'Pause' : 'Resume',
                style: TextStyle(
                  fontSize: isNarrow ? 10.5 : 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12),
                foregroundColor: const Color(0xFFF95B1C),
                side: const BorderSide(color: Color(0xFFF95B1C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 18),
            tooltip: 'Options',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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

  Widget _buildStatusBadge({bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 2 : 4,
      ),
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
            radius: isCompact ? 2.5 : 3.5,
            backgroundColor: _currentCampaign.isCompleted
                ? const Color(0xFF16A34A)
                : (_currentCampaign.isRunning ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
          ),
          SizedBox(width: isCompact ? 3 : 5),
          Text(
            _currentCampaign.status.toUpperCase(),
            style: TextStyle(
              fontSize: isCompact ? 9.5 : 11,
              fontWeight: FontWeight.w800,
              color: _currentCampaign.isCompleted
                  ? const Color(0xFF15803D)
                  : (_currentCampaign.isRunning ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isNarrow) {
    final tabs = ['Overview', 'Delivery Report', 'Customer List', 'Message Preview'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _activeTab == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeTab = t),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 12 : 16,
                  vertical: isNarrow ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF031024),
                            Color(0xFF072146),
                            Color(0xFF0A2E5C),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x28031024),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontSize: isNarrow ? 11 : 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsRow(bool isNarrow) {
    final stats = _currentCampaign.stats;
    final openRate = stats.messagesSent > 0
        ? ((stats.read / stats.messagesSent) * 100).toStringAsFixed(1)
        : (stats.read > 0 ? '70.0' : '0.0');
    final failRate = stats.totalRecipients > 0
        ? ((stats.failed / stats.totalRecipients) * 100).toStringAsFixed(1)
        : '0.0';

    final sentCard = _buildMetricCard(
      'Messages Sent',
      '${stats.messagesSent}',
      Icons.send_rounded,
      const Color(0xFF6366F1),
      const Color(0xFFEEF2FF),
      isNarrow: isNarrow,
    );

    final deliveredCard = _buildMetricCard(
      'Delivered',
      '${stats.delivered}',
      Icons.done_all_rounded,
      const Color(0xFF10B981),
      const Color(0xFFECFDF5),
      badge: '${stats.deliveryRate > 0 ? stats.deliveryRate.toStringAsFixed(1) : (stats.messagesSent > 0 ? "100.0" : "0.0")}%',
      isNarrow: isNarrow,
    );

    final openCard = _buildMetricCard(
      'Open (Read)',
      '${stats.read}',
      Icons.mark_email_read_rounded,
      const Color(0xFF0EA5E9),
      const Color(0xFFF0F9FF),
      badge: '$openRate%',
      isNarrow: isNarrow,
    );

    final failedCard = _buildMetricCard(
      'Failed',
      '${stats.failed}',
      Icons.error_outline_rounded,
      const Color(0xFFEF4444),
      const Color(0xFFFEF2F2),
      badge: '$failRate%',
      isNegative: stats.failed > 0,
      isNarrow: isNarrow,
    );

    if (isNarrow) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: sentCard),
              const SizedBox(width: 8),
              Expanded(child: deliveredCard),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: openCard),
              const SizedBox(width: 8),
              Expanded(child: failedCard),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: sentCard),
        const SizedBox(width: 14),
        Expanded(child: deliveredCard),
        const SizedBox(width: 14),
        Expanded(child: openCard),
        const SizedBox(width: 14),
        Expanded(child: failedCard),
      ],
    );
  }

  Widget _buildRecipientsBreakdownCard(bool isNarrow) {
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
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 12 : 20,
              vertical: isNarrow ? 10 : 14,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFFF95B1C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recipient Delivery & Read Status',
                    style: TextStyle(
                      fontSize: isNarrow ? 12.5 : 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 6 : 10,
                    vertical: isNarrow ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${recipients.isNotEmpty ? recipients.length : _currentCampaign.stats.totalRecipients} Recipient(s)',
                    style: TextStyle(
                      fontSize: isNarrow ? 10 : 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (recipients.isEmpty)
            Padding(
              padding: EdgeInsets.all(isNarrow ? 16 : 24),
              child: Center(
                child: Text(
                  'Audience: ${_currentCampaign.audience.groupName} (${_currentCampaign.stats.totalRecipients > 0 ? _currentCampaign.stats.totalRecipients : 1} contacts queued).',
                  style: TextStyle(fontSize: isNarrow ? 11 : 12.5, color: const Color(0xFF64748B)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: isNarrow ? 560 : 0),
                child: SizedBox(
                  width: isNarrow ? 560 : null,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 12 : 20,
                          vertical: 8,
                        ),
                        color: const Color(0xFFF8FAFC),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('Customer / Phone', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                            Expanded(flex: 2, child: Text('Status', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                            Expanded(flex: 2, child: Text('Sent / Delivered Time', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                            Expanded(flex: 3, child: Text('Message ID / Note', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 12 : 20,
                              vertical: isNarrow ? 8 : 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: isNarrow ? 26 : 32,
                                        height: isNarrow ? 26 : 32,
                                        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                                        child: Center(
                                          child: Icon(Icons.person, size: isNarrow ? 13 : 16, color: const Color(0xFF64748B)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.phone,
                                              style: TextStyle(
                                                fontSize: isNarrow ? 11.5 : 13,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              r.name.isNotEmpty ? r.name : 'Customer',
                                              style: TextStyle(fontSize: isNarrow ? 10 : 11, color: const Color(0xFF94A3B8)),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(badgeIcon, size: 11, color: badgeText),
                                          const SizedBox(width: 3),
                                          Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: isNarrow ? 9.5 : 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: badgeText,
                                            ),
                                          ),
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
                                    style: TextStyle(fontSize: isNarrow ? 10.5 : 11.5, color: const Color(0xFF64748B)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    r.error != null && r.error!.isNotEmpty
                                        ? r.error!
                                        : (r.messageId ?? 'Processed via WhatsApp Cloud API'),
                                    style: TextStyle(
                                      fontSize: isNarrow ? 10 : 11,
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
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color bgColor, {
    String? badge,
    bool isNegative = false,
    bool isNarrow = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 10 : 16,
        vertical: isNarrow ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isNarrow ? 10.5 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: isNarrow ? 26 : 32,
                height: isNarrow ? 26 : 32,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: isNarrow ? 13 : 16),
              ),
            ],
          ),
          SizedBox(height: isNarrow ? 4 : 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isNarrow ? 16 : 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (badge != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 4 : 6,
                    vertical: isNarrow ? 1.5 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: isNegative ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: isNarrow ? 9.5 : 10.5,
                      fontWeight: FontWeight.w700,
                      color: isNegative ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isNarrow) {
    final completion = _currentCampaign.stats.completionRate;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Status: ', style: TextStyle(fontSize: isNarrow ? 11 : 12, color: const Color(0xFF64748B))),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 6 : 8,
                      vertical: isNarrow ? 2 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(radius: 3, backgroundColor: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          _currentCampaign.isRunning ? 'Running' : 'Scheduled',
                          style: TextStyle(fontSize: isNarrow ? 10 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Scheduled: ', style: TextStyle(fontSize: isNarrow ? 11 : 12, color: const Color(0xFF64748B))),
                  Text(
                    _currentCampaign.estimatedSendingTime.isNotEmpty
                        ? _currentCampaign.estimatedSendingTime
                        : '25 Oct 2026, 11:00 AM',
                    style: TextStyle(fontSize: isNarrow ? 11 : 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Text(
                'Est: ${completion.toStringAsFixed(0)}% Complete',
                style: TextStyle(fontSize: isNarrow ? 11 : 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (completion / 100).clamp(0.0, 1.0),
              minHeight: isNarrow ? 6 : 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostWalletCard(bool isNarrow) {
    final cost = _currentCampaign.cost;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 14 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cost & Wallet',
            style: TextStyle(fontSize: isNarrow ? 12.5 : 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          ),
          SizedBox(height: isNarrow ? 10 : 16),
          _buildCostDetail('Total', '₹${cost.totalAmount.toStringAsFixed(2)}', isNarrow: isNarrow),
          _buildCostDetail('Spent So Far', '₹${cost.spentSoFar.toStringAsFixed(2)}', isNarrow: isNarrow),
          _buildCostDetail('Remaining', '₹${cost.remaining.toStringAsFixed(2)}', isNarrow: isNarrow),
          SizedBox(height: isNarrow ? 12 : 18),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: isNarrow ? 34 : 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF031024),
                    Color(0xFF072146),
                    Color(0xFF0A2E5C),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x28031024),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'View Wallet',
                  style: TextStyle(
                    fontSize: isNarrow ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostDetail(String label, String value, {bool isNarrow = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isNarrow ? 8 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isNarrow ? 11 : 12.5, color: const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: isNarrow ? 11.5 : 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildDeliveryChartCard(bool isNarrow) {
    final timeline = _currentCampaign.deliveryTimeline;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 14 : 22),
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
              Text(
                'Delivery Chart',
                style: TextStyle(fontSize: isNarrow ? 12.5 : 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  _buildLegendItem('Sent', const Color(0xFF2563EB), isNarrow: isNarrow),
                  SizedBox(width: isNarrow ? 8 : 14),
                  _buildLegendItem('Delivered', const Color(0xFF10B981), isNarrow: isNarrow),
                ],
              ),
            ],
          ),
          SizedBox(height: isNarrow ? 12 : 18),
          SizedBox(
            height: isNarrow ? 110 : 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _DeliveryChartPainter(points: timeline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isNarrow = false}) {
    return Row(
      children: [
        CircleAvatar(radius: isNarrow ? 3 : 4, backgroundColor: color),
        SizedBox(width: isNarrow ? 4 : 5),
        Text(label, style: TextStyle(fontSize: isNarrow ? 10.5 : 11.5, fontWeight: FontWeight.w600, color: color)),
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
