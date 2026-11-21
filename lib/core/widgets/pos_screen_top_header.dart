import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../services/sound_service.dart';
import '../services/wallet_service.dart';
import '../widgets/connection_status_badge.dart';
import '../widgets/glass_company_name_badge.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/notifications/services/notification_service.dart';

class SmoothBrandLogoWidget extends StatelessWidget {
  final double size;
  final String? logoPath;
  final String companyName;

  const SmoothBrandLogoWidget({
    super.key,
    required this.size,
    this.logoPath,
    this.companyName = 'Apna POS',
  });

  static final Map<String, Uint8List> _base64Cache = {};

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    final path = logoPath?.trim();
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('data:image') ||
          path.startsWith('data:') ||
          (path.length > 60 && !path.startsWith('http') && !path.startsWith('assets/'))) {
        try {
          Uint8List? bytes = _base64Cache[path];
          if (bytes == null) {
            final clean = path.contains(',') ? path.split(',').last : path;
            bytes = base64Decode(clean.replaceAll('\n', '').replaceAll('\r', '').trim());
            _base64Cache[path] = bytes;
          }
          return Image.memory(
            bytes,
            key: ValueKey('mem_${path.hashCode}'),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } catch (_) {}
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          key: ValueKey('net_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          key: ValueKey('asset_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else if (!kIsWeb && !path.contains('_selected')) {
        try {
          final f = File(path);
          if (f.existsSync()) {
            return Image.file(
              f,
              key: ValueKey('file_$path'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => _buildFallback(),
            );
          }
        } catch (_) {}
      }
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Image.asset(
      'assets/images/logo.png',
      key: const ValueKey('default_brand_logo_png'),
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _buildInitialFallback(),
    );
  }

  Widget _buildInitialFallback() {
    String initial = 'P';
    if (companyName.trim().isNotEmpty) {
      initial = companyName.trim()[0].toUpperCase();
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0F3E57), Color(0xFF08253A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class PosScreenTopHeader extends StatelessWidget {
  final VoidCallback? onLogoTap;
  final VoidCallback? onStoreTap;

  const PosScreenTopHeader({
    super.key,
    this.onLogoTap,
    this.onStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final rest = db.restaurant;
    final user = db.currentUser;
    final companyTitle = rest?.name ?? user?.companyName ?? 'Pizza 47';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      color: Colors.transparent,
      child: Row(
        children: [
          // Circular Brand Logo
          InkWell(
            onTap: onLogoTap ?? () => _showStoreInfoSheet(context, companyTitle),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: ClipOval(
                child: SmoothBrandLogoWidget(
                  size: 36,
                  logoPath: db.companyLogoPath,
                  companyName: companyTitle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Glass Company Name Badge ("Pizza 47 ▼")
          Flexible(
            child: GlassCompanyNameBadge(
              name: companyTitle,
              hasDropdown: true,
              isDropdownOpen: false,
              isNeumorphic: false,
              onTap: onStoreTap ?? () => _showStoreInfoSheet(context, companyTitle),
            ),
          ),

          const SizedBox(width: 6),
          const Spacer(),

          // ONLINE / OFFLINE STATUS DOT INDICATOR
          const GlassConnectionStatusBadge(isDarkTheme: true),
          const SizedBox(width: 6),

          // WALLET KHAZANA BUTTON
          _buildWalletButton(context),
          const SizedBox(width: 6),

          // NOTIFICATION BELL BUTTON
          _buildNotificationBellButton(context),
        ],
      ),
    );
  }

  void _showStoreInfoSheet(BuildContext context, String companyTitle) {
    final db = DatabaseService();
    final user = db.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SmoothBrandLogoWidget(
                  size: 44,
                  logoPath: db.companyLogoPath,
                  companyName: companyTitle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F2B48),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user != null
                            ? 'Logged in as ${user.name} (${user.role})'
                            : 'Apna POS Active Session',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletButton(BuildContext context) {
    return Tooltip(
      message: 'Khazana Wallet',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            SoundService.playButtonClick();
            _showWalletInfo(context);
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.1,
              ),
            ),
            child: Image.asset(
              'assets/images/wallet_icon.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWalletInfo(BuildContext context) {
    WalletService().getWalletDetails().then((_) {}, onError: (_) {});
    final balance = WalletService().balance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Khazana Wallet Balance: \u20B9${balance.toStringAsFixed(2)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildNotificationBellButton(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationService(),
      builder: (context, _) {
        final unreadCount = NotificationService().unreadCount;
        final hasNotification = unreadCount > 0 ||
            NotificationService().notifications.any((n) => !n.isRead);

        return Tooltip(
          message: hasNotification
              ? 'Notifications ($unreadCount unread)'
              : 'Notifications',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.1,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    if (hasNotification)
                      Positioned(
                        top: 2.5,
                        right: 2.5,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF051C48),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66EF4444),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
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
