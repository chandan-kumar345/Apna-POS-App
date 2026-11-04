import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/models/table_model.dart';
import '../storefront/screens/customer_storefront_screen.dart';

/// Table Stand Themes for QR Stand Printing
enum TableStandTheme {
  crimsonRuby,
  royalEmerald,
  sapphireBlue,
  sunsetAmber,
  midnightGold,
  modernClean,
}

class StandThemeConfig {
  final String label;
  final String subtitle;
  final List<Color> headerGradient;
  final Color cardBg;
  final Color tableBadgeBg;
  final Color tableBadgeText;
  final Color qrBorderColor;
  final Color qrEyeColor;
  final Color qrDataColor;
  final Color bodyTextColor;
  final Color subTextColor;
  final Color accentPillBg;
  final Color accentPillText;
  final bool isDarkCard;

  const StandThemeConfig({
    required this.label,
    required this.subtitle,
    required this.headerGradient,
    required this.cardBg,
    required this.tableBadgeBg,
    required this.tableBadgeText,
    required this.qrBorderColor,
    required this.qrEyeColor,
    required this.qrDataColor,
    required this.bodyTextColor,
    required this.subTextColor,
    required this.accentPillBg,
    required this.accentPillText,
    this.isDarkCard = false,
  });
}

class TableQrDownloadScreen extends StatefulWidget {
  final String? initialTableCode;

  const TableQrDownloadScreen({
    super.key,
    this.initialTableCode,
  });

  @override
  State<TableQrDownloadScreen> createState() => _TableQrDownloadScreenState();
}

class _TableQrDownloadScreenState extends State<TableQrDownloadScreen> {
  final DatabaseService _db = DatabaseService();
  final Map<String, GlobalKey> _cardKeys = {};

  TableStandTheme _currentTheme = TableStandTheme.crimsonRuby;
  String _selectedFloor = 'All';
  String _searchQuery = '';
  bool _isDownloadingAll = false;
  final String _restaurantCode = 'R1';

  @override
  void initState() {
    super.initState();
    _initKeys();
  }

  RestaurantModel? get _restaurant => _db.restaurant;

  /// Max table limit for this business
  int get _maxTableCount {
    final configured = _restaurant?.tableCount ?? 0;
    final maxDbNum = _db.tables.fold<int>(0, (prev, t) => t.tableNumber > prev ? t.tableNumber : prev);
    final count = configured > 0 ? configured : (maxDbNum > 0 ? maxDbNum : _db.tables.length);
    return count > 0 ? count : 20;
  }

  /// All valid tables strictly bounded by _maxTableCount (1 to _maxTableCount)
  List<TableModel> get _allValidTables {
    final total = _maxTableCount;
    final existingMap = {for (final t in _db.tables) t.tableNumber: t};
    final List<TableModel> result = [];
    for (int i = 1; i <= total; i++) {
      if (existingMap.containsKey(i)) {
        result.add(existingMap[i]!);
      } else {
        result.add(TableModel(
          id: 'TBL_AUTO_$i',
          tableNumber: i,
          name: 'Table ${i.toString().padLeft(2, '0')}',
          floor: 'Ground Floor',
          capacity: 4,
          status: TableStatus.free,
          position: i,
        ));
      }
    }
    return result;
  }

  void _initKeys() {
    for (final table in _allValidTables) {
      final keyId = 'table_${table.id}_${table.tableNumber}';
      if (!_cardKeys.containsKey(keyId)) {
        _cardKeys[keyId] = GlobalKey();
      }
    }
  }

  String get _companySlug {
    final slug = _restaurant?.storefrontSlug.trim() ?? '';
    if (slug.isNotEmpty) return slug.toLowerCase();
    final name = _restaurant?.name.trim() ?? 'store';
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _formatTableCode(int tableNum) {
    return 'T${tableNum.toString().padLeft(2, '0')}';
  }

  String _buildTableDirectUrl(int tableNum) {
    final tCode = _formatTableCode(tableNum);
    return 'https://apnaposs.vercel.app/$_companySlug/R=$_restaurantCode&T=$tCode';
  }

  String _buildTableDisplayUrl(int tableNum) {
    final tCode = _formatTableCode(tableNum);
    return 'apnaposs.vercel.app/$_companySlug/R=$_restaurantCode&T=$tCode';
  }

  List<String> get _floors {
    final list = _allValidTables.map((t) => t.floor.trim()).where((f) => f.isNotEmpty).toSet().toList();
    list.sort();
    return ['All', ...list];
  }

  List<TableModel> get _filteredTables {
    var list = _allValidTables;
    if (_selectedFloor != 'All') {
      list = list.where((t) => t.floor.trim() == _selectedFloor).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((t) {
        final tNumStr = t.tableNumber.toString();
        final tName = t.name.toLowerCase();
        final code = _formatTableCode(t.tableNumber).toLowerCase();
        return tNumStr.contains(q) || tName.contains(q) || code.contains(q);
      }).toList();
    }
    return list;
  }

  StandThemeConfig _getThemeConfig(TableStandTheme theme) {
    switch (theme) {
      case TableStandTheme.crimsonRuby:
        return const StandThemeConfig(
          label: 'Crimson Ruby & Gold',
          subtitle: 'Vibrant ruby gradient with amber gold accents',
          headerGradient: [Color(0xFF881337), Color(0xFFBE123C)],
          cardBg: Colors.white,
          tableBadgeBg: Color(0xFFF59E0B),
          tableBadgeText: Color(0xFF451A03),
          qrBorderColor: Color(0xFFBE123C),
          qrEyeColor: Color(0xFF881337),
          qrDataColor: Color(0xFF4C0519),
          bodyTextColor: Color(0xFF0F172A),
          subTextColor: Color(0xFF475569),
          accentPillBg: Color(0xFFFFF1F2),
          accentPillText: Color(0xFFBE123C),
        );
      case TableStandTheme.royalEmerald:
        return const StandThemeConfig(
          label: 'Royal Emerald & Mint',
          subtitle: 'Deep forest emerald with fresh mint accents',
          headerGradient: [Color(0xFF064E3B), Color(0xFF047857)],
          cardBg: Colors.white,
          tableBadgeBg: Color(0xFF10B981),
          tableBadgeText: Colors.white,
          qrBorderColor: Color(0xFF059669),
          qrEyeColor: Color(0xFF064E3B),
          qrDataColor: Color(0xFF064E3B),
          bodyTextColor: Color(0xFF0F172A),
          subTextColor: Color(0xFF475569),
          accentPillBg: Color(0xFFECFDF5),
          accentPillText: Color(0xFF047857),
        );
      case TableStandTheme.sapphireBlue:
        return const StandThemeConfig(
          label: 'Sapphire Blue & Cyan',
          subtitle: 'Cobalt electric blue with neon cyan accents',
          headerGradient: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          cardBg: Colors.white,
          tableBadgeBg: Color(0xFF0284C7),
          tableBadgeText: Colors.white,
          qrBorderColor: Color(0xFF2563EB),
          qrEyeColor: Color(0xFF1E3A8A),
          qrDataColor: Color(0xFF0F172A),
          bodyTextColor: Color(0xFF0F172A),
          subTextColor: Color(0xFF475569),
          accentPillBg: Color(0xFFEFF6FF),
          accentPillText: Color(0xFF1D4ED8),
        );
      case TableStandTheme.sunsetAmber:
        return const StandThemeConfig(
          label: 'Sunset Terracotta & Amber',
          subtitle: 'Fiery warm terracotta with sunburst yellow',
          headerGradient: [Color(0xFF7C2D12), Color(0xFFEA580C)],
          cardBg: Colors.white,
          tableBadgeBg: Color(0xFFFBBF24),
          tableBadgeText: Color(0xFF431407),
          qrBorderColor: Color(0xFFEA580C),
          qrEyeColor: Color(0xFF7C2D12),
          qrDataColor: Color(0xFF431407),
          bodyTextColor: Color(0xFF0F172A),
          subTextColor: Color(0xFF475569),
          accentPillBg: Color(0xFFFFF7ED),
          accentPillText: Color(0xFFC2410C),
        );
      case TableStandTheme.midnightGold:
        return const StandThemeConfig(
          label: 'Midnight Obsidian & 24K Gold',
          subtitle: 'Ultra-luxurious dark mode with glowing gold',
          headerGradient: [Color(0xFF090D16), Color(0xFF1E293B)],
          cardBg: Color(0xFF0B1120),
          tableBadgeBg: Color(0xFFF59E0B),
          tableBadgeText: Color(0xFF0A0F1D),
          qrBorderColor: Color(0xFFF59E0B),
          qrEyeColor: Color(0xFF0A0F1D),
          qrDataColor: Color(0xFF0A0F1D),
          bodyTextColor: Color(0xFFF8FAFC),
          subTextColor: Color(0xFF94A3B8),
          accentPillBg: Color(0xFF1E293B),
          accentPillText: Color(0xFFF59E0B),
          isDarkCard: true,
        );
      case TableStandTheme.modernClean:
        return const StandThemeConfig(
          label: 'Modern Clean Studio',
          subtitle: 'High contrast electric blue and crisp white',
          headerGradient: [Color(0xFF0052FF), Color(0xFF3B82F6)],
          cardBg: Colors.white,
          tableBadgeBg: Color(0xFF0052FF),
          tableBadgeText: Colors.white,
          qrBorderColor: Color(0xFF0052FF),
          qrEyeColor: Color(0xFF051C48),
          qrDataColor: Color(0xFF0F172A),
          bodyTextColor: Color(0xFF0F172A),
          subTextColor: Color(0xFF475569),
          accentPillBg: Color(0xFFEEF2FF),
          accentPillText: Color(0xFF0052FF),
        );
    }
  }

  /// Profile logo resolver with flawless offline / network / monogram fallback
  Widget _buildProfileLogoWidget({
    required double size,
    required Color borderColor,
    double borderWidth = 2.0,
    bool isCircular = true,
  }) {
    final logoPath = _db.companyLogoPath ?? _restaurant?.logoUrl;
    final restName = _restaurant?.name.trim() ?? 'AP';
    final initial = restName.isNotEmpty ? restName[0].toUpperCase() : 'A';

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(size * 0.2),
        gradient: const LinearGradient(
          colors: [Color(0xFF0052FF), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.46,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (logoPath == null || logoPath.trim().isEmpty || logoPath.contains('assets/images/logo.png')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircular ? null : BorderRadius.circular(size * 0.2),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: ClipRRect(
          borderRadius: isCircular ? BorderRadius.circular(size) : BorderRadius.circular(size * 0.2),
          child: fallback,
        ),
      );
    }

    final clean = logoPath.trim();
    Widget imageWidget;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      imageWidget = Image.network(
        clean,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (clean.startsWith('assets/')) {
      imageWidget = Image.asset(
        clean,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      final file = File(clean);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      } else {
        imageWidget = fallback;
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(size * 0.2),
        border: Border.all(color: borderColor, width: borderWidth),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: isCircular ? BorderRadius.circular(size) : BorderRadius.circular(size * 0.2),
        child: imageWidget,
      ),
    );
  }

  Future<Uint8List?> _captureWidgetImage(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[TableQrDownloadScreen] Error capturing card: $e');
      return null;
    }
  }

  Future<void> _downloadTableQrImage(TableModel table) async {
    final keyId = 'table_${table.id}_${table.tableNumber}';
    final key = _cardKeys[keyId];
    if (key == null) return;

    try {
      final bytes = await _captureWidgetImage(key);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate image. Please try again.')),
          );
        }
        return;
      }

      final tCode = _formatTableCode(table.tableNumber);
      final fileName = 'Table_${tCode}_QR_Order.png';

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saved $fileName to device storage',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Scan to order at ${table.name}')),
              ),
            ),
          );
        }
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
          text: 'Table $tCode QR Code',
        ));
      }
    } catch (e) {
      debugPrint('[TableQrDownloadScreen] Download error: $e');
    }
  }

  Future<void> _shareTableQr(TableModel table) async {
    final keyId = 'table_${table.id}_${table.tableNumber}';
    final key = _cardKeys[keyId];
    final directUrl = _buildTableDirectUrl(table.tableNumber);
    final tCode = _formatTableCode(table.tableNumber);

    try {
      Uint8List? bytes;
      if (key != null) {
        bytes = await _captureWidgetImage(key);
      }

      final restName = _restaurant?.name ?? 'Restaurant';
      final shareText = '🍽️ $restName - ${table.name} ($tCode)\nScan to view our digital menu and order directly from your table:\n$directUrl';
      if (bytes != null && !kIsWeb) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Table_${tCode}_QR.png');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: shareText));
      } else {
        await SharePlus.instance.share(ShareParams(text: shareText));
      }
    } catch (e) {
      debugPrint('[TableQrDownloadScreen] Share error: $e');
    }
  }

  Future<void> _downloadAllTableQrs() async {
    if (_isDownloadingAll) return;
    setState(() => _isDownloadingAll = true);

    try {
      int successCount = 0;
      final List<XFile> filesToShare = [];

      for (final table in _filteredTables) {
        final keyId = 'table_${table.id}_${table.tableNumber}';
        final key = _cardKeys[keyId];
        if (key != null) {
          final bytes = await _captureWidgetImage(key);
          if (bytes != null) {
            final tCode = _formatTableCode(table.tableNumber);
            final fileName = 'Table_${tCode}_Stand.png';
            if (!kIsWeb) {
              final dir = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/$fileName');
              await file.writeAsBytes(bytes);
              filesToShare.add(XFile(file.path));
            }
            successCount++;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_done_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Downloaded $successCount Table QR stand cards successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0052FF),
            behavior: SnackBarBehavior.floating,
            action: filesToShare.isNotEmpty
                ? SnackBarAction(
                    label: 'Share All',
                    textColor: Colors.white,
                    onPressed: () => SharePlus.instance.share(ShareParams(files: filesToShare, text: 'All Table QR Stands - ${_restaurant?.name}')),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TableQrDownloadScreen] Error downloading all: $e');
    } finally {
      if (mounted) {
        setState(() => _isDownloadingAll = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard: $text'),
        backgroundColor: const Color(0xFF051C48),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openStorefrontPreview(TableModel table) {
    final tCode = _formatTableCode(table.tableNumber);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerStorefrontScreen(
          slug: _companySlug,
          tableCode: tCode,
          restaurantCode: _restaurantCode,
          isPreviewMode: true,
        ),
      ),
    );
  }

  void _showEditTableCountDialog() {
    final ctrl = TextEditingController(text: _maxTableCount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.table_restaurant_rounded, color: Color(0xFF0052FF)),
            SizedBox(width: 10),
            Text('Configure Total Tables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the total number of dining tables available at your outlet. Only tables up to this count will be generated and accessible by customers.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Total Tables',
                hintText: 'e.g. 20',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.pin_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCount = int.tryParse(ctrl.text.trim()) ?? 0;
              if (newCount > 0 && newCount <= 200) {
                Navigator.pop(ctx);
                await _db.syncTableCount(newCount);
                if (mounted) {
                  setState(() {
                    _cardKeys.clear();
                    _initKeys();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated to $newCount tables successfully.'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Count', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initKeys();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B132B) : const Color(0xFFEEF2F6);
    final cardBgColor = isDark ? const Color(0xFF1C2541) : Colors.white;
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF101B3B) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Table QR Ordering Hub',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'apnaposs.vercel.app/$_companySlug/R=$_restaurantCode&T=T01',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0052FF),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _isDownloadingAll ? null : _downloadAllTableQrs,
              icon: _isDownloadingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _isDownloadingAll ? 'Saving...' : 'Download All',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052FF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HERO CARD: STOREFRONT & TABLE LIMIT GUARD
            _buildStorefrontBannerCard(cardBgColor, textDark, textMuted),

            const SizedBox(height: 20),

            // 2. THEME & FLOOR FILTER CONTROLS
            _buildFilterAndThemeBar(cardBgColor, textDark, textMuted),

            const SizedBox(height: 20),

            // 3. TABLE QR CARDS GRID
            if (_filteredTables.isEmpty)
              _buildEmptyState(cardBgColor, textDark, textMuted)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width > 1100 ? 3 : (width > 680 ? 2 : 1);
                  final itemWidth = (width - ((crossAxisCount - 1) * 16)) / crossAxisCount;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 20,
                    children: _filteredTables.map((table) {
                      return SizedBox(
                        width: itemWidth,
                        child: _buildTableCard(table, cardBgColor, textDark, textMuted),
                      );
                    }).toList(),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStorefrontBannerCard(Color cardBg, Color textDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF0052FF).withValues(alpha: 0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProfileLogoWidget(
                size: 50,
                borderColor: const Color(0xFF0052FF),
                borderWidth: 2,
                isCircular: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _restaurant?.name.toUpperCase() ?? 'RESTAURANT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ONLINE LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When customers scan any table QR, the menu opens instantly with that dining table pre-selected.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Table Limit Guard Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, color: Color(0xFF059669), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                      children: [
                        const TextSpan(text: 'Table Limit Guard: ', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(
                          text: '$_maxTableCount Tables Active (T01 – T${_maxTableCount.toString().padLeft(2, "0")}). ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: 'Links for tables beyond this count (e.g. Table 21+) are strictly blocked.',
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showEditTableCountDialog,
                  icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF059669)),
                  label: const Text('Edit Count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Base Link
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF0052FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'https://apnaposs.vercel.app/$_companySlug/R=$_restaurantCode&T={T01..T${_maxTableCount.toString().padLeft(2, "0")}}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy Storefront Link',
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                  onPressed: () => _copyToClipboard(
                    'https://apnaposs.vercel.app/$_companySlug',
                    'Base Storefront Link',
                  ),
                ),
                IconButton(
                  tooltip: 'Open Web Menu in Browser',
                  icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF0052FF)),
                  onPressed: () async {
                    final uri = Uri.parse('https://apnaposs.vercel.app/$_companySlug');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndThemeBar(Color cardBg, Color textDark, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Search Input
            Expanded(
              flex: 2,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search table (e.g. 01, Table 5)...',
                    hintStyle: TextStyle(fontSize: 13, color: textMuted),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Stand Theme Dropdown
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TableStandTheme>(
                  value: _currentTheme,
                  icon: const Icon(Icons.palette_outlined, size: 18, color: Color(0xFF0052FF)),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
                  onChanged: (val) {
                    if (val != null) setState(() => _currentTheme = val);
                  },
                  items: TableStandTheme.values.map((t) {
                    final cfg = _getThemeConfig(t);
                    return DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: cfg.headerGradient),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(cfg.label),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Floor Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _floors.map((floor) {
              final isSelected = _selectedFloor == floor;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(floor == 'All' ? 'All Tables ($_maxTableCount)' : floor),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFloor = floor),
                  selectedColor: const Color(0xFF0052FF).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF0052FF),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0052FF) : textDark,
                  ),
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0052FF) : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCard(TableModel table, Color cardBg, Color textDark, Color textMuted) {
    final keyId = 'table_${table.id}_${table.tableNumber}';
    final cardKey = _cardKeys.putIfAbsent(keyId, () => GlobalKey());
    final directUrl = _buildTableDirectUrl(table.tableNumber);
    final displayUrl = _buildTableDisplayUrl(table.tableNumber);
    final tCode = _formatTableCode(table.tableNumber);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. VISUAL REPAINT BOUNDARY: EXACT PHYSICAL STAND TO PRINT / DOWNLOAD
          RepaintBoundary(
            key: cardKey,
            child: _buildPhysicalStandWidget(table, tCode, directUrl, displayUrl),
          ),

          // 2. CARD CONTROLS / ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Quick info & Direct URL
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayUrl,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0052FF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy Link',
                      onPressed: () => _copyToClipboard(directUrl, 'Table $tCode QR Link'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF00897B)),
                      tooltip: 'Preview Customer Web Screen',
                      onPressed: () => _openStorefrontPreview(table),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Action buttons: Download, Share
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadTableQrImage(table),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF051C48),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareTableQr(table),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Physical Table Tent Stand preview (rendered to PNG on download / print)
  Widget _buildPhysicalStandWidget(
    TableModel table,
    String tCode,
    String directUrl,
    String displayUrl,
  ) {
    final cfg = _getThemeConfig(_currentTheme);

    return Container(
      decoration: BoxDecoration(
        color: cfg.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TOP HEADER BANNER (Vibrant Theme Gradient + Profile Logo + Store Name)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cfg.headerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                // Profile Logo Avatar
                _buildProfileLogoWidget(
                  size: 46,
                  borderColor: Colors.white,
                  borderWidth: 2.0,
                  isCircular: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _restaurant?.name.toUpperCase() ?? 'RESTAURANT',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: Colors.white,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _restaurant?.tagline.isNotEmpty == true
                            ? _restaurant!.tagline
                            : 'SCAN TO ORDER AT YOUR TABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. MAIN STAND BODY
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                // Vibrant Table Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: cfg.tableBadgeBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: cfg.tableBadgeBg.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_restaurant_rounded, size: 18, color: cfg.tableBadgeText),
                      const SizedBox(width: 6),
                      Text(
                        'TABLE $tCode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: cfg.tableBadgeText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cfg.tableBadgeText.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          table.floor.isNotEmpty ? table.floor : 'Ground Floor',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cfg.tableBadgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Scannable QR Code Frame with Centered Embedded Profile Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cfg.qrBorderColor.withValues(alpha: 0.6), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // QR Code with highest error correction for logo overlay tolerance
                      QrImageView(
                        data: directUrl,
                        version: QrVersions.auto,
                        size: 175,
                        gapless: true,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: cfg.qrEyeColor,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: cfg.qrDataColor,
                        ),
                      ),

                      // Embedded Profile Logo in Center of QR Code
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: _buildProfileLogoWidget(
                          size: 39,
                          borderColor: cfg.qrBorderColor,
                          borderWidth: 1.5,
                          isCircular: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // High Visibility Callout
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 16, color: cfg.qrBorderColor),
                    const SizedBox(width: 6),
                    Text(
                      'POINT CAMERA TO VIEW MENU & ORDER',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: cfg.bodyTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'No app download required • Orders go directly to the kitchen',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cfg.subTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Monospace URL Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cfg.accentPillBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayUrl,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cfg.accentPillText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),

                // Security & Brand Verification Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Table ${table.tableNumber} of $_maxTableCount • Apna POS Verified Stand',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: cfg.subTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color cardBg, Color textDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.table_restaurant_outlined, size: 48, color: textMuted),
          const SizedBox(height: 14),
          Text(
            'No Tables Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search query or floor filter.',
            style: TextStyle(fontSize: 13, color: textMuted),
          ),
        ],
      ),
    );
  }
}
