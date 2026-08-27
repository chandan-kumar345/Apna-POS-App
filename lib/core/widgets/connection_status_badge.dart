import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../database/database_service.dart';

/// Interactive Header Badge that displays real-time Online/Offline status & Cloud Sync indicators.
class GlassConnectionStatusBadge extends StatefulWidget {
  final bool compact;
  final bool isDarkTheme;

  const GlassConnectionStatusBadge({
    super.key,
    this.compact = false,
    this.isDarkTheme = true,
  });

  @override
  State<GlassConnectionStatusBadge> createState() => _GlassConnectionStatusBadgeState();
}

class _GlassConnectionStatusBadgeState extends State<GlassConnectionStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final NetworkService _networkService = NetworkService();
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _db.addListener(_onDbUpdate);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _db.removeListener(_onDbUpdate);
    super.dispose();
  }

  void _onDbUpdate() {
    if (mounted) setState(() {});
  }

  void _showSyncSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isOnline = _networkService.isOnline;
            final unsynced = _db.unsyncedOrdersCount;
            final isSyncing = _db.isSyncing;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -4)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          color: isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'System is Online & Connected' : 'System is Running Offline',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOnline
                                  ? 'All sales, orders & bills are automatically synced to the cloud database.'
                                  : 'Billing works seamlessly offline. Orders will auto-sync once Wi-Fi/Internet connects.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Data Summary Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Local Orders in Device', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text(
                              '${_db.orders.length}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Unsynced Offline Orders', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: unsynced > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                unsynced > 0 ? '$unsynced Pending' : 'All Synced (0)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: unsynced > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSyncing
                          ? null
                          : () async {
                              setModalState(() {});
                              await _networkService.checkNow();
                              await _db.syncWithBackend();
                              if (modalCtx.mounted) {
                                setModalState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _networkService.isOnline
                                          ? 'Cloud synchronization complete!'
                                          : 'Device is offline. Local data is safely preserved.',
                                    ),
                                    backgroundColor: _networkService.isOnline
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      icon: isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(isSyncing ? 'Syncing...' : 'Sync Cloud Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _networkService.isOnlineNotifier,
      builder: (context, isOnline, _) {
        final unsynced = _db.unsyncedOrdersCount;
        final isSyncing = _db.isSyncing;

        final Color dotColor = isOnline ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
        final String tooltipText = isOnline
            ? (unsynced > 0 ? 'Online • $unsynced orders syncing' : 'Online • Connected to Cloud')
            : 'Offline • $unsynced pending sync';

        return Tooltip(
          message: tooltipText,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showSyncSheet,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFF22C55E).withOpacity(0.4)
                        : const Color(0xFFEF4444).withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated pulsing dot
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withOpacity(0.4 + (_pulseController.value * 0.4)),
                                blurRadius: 6 + (_pulseController.value * 4),
                                spreadRadius: _pulseController.value * 2,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Sync spinner if actively syncing
                    if (isSyncing)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: dotColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
