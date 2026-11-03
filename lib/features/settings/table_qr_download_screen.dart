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
  modernClean,
  midnightDark,
  warmWood,
  acrylicMinimal,
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

  TableStandTheme _currentTheme = TableStandTheme.modernClean;
  String _selectedFloor = 'All';
  String _searchQuery = '';
  bool _isDownloadingAll = false;
  final String _restaurantCode = 'R1';

  @override
  void initState() {
    super.initState();
    _initKeys();
  }

  void _initKeys() {
    for (final table in _db.tables) {
      final keyId = 'table_${table.id}_${table.tableNumber}';
      if (!_cardKeys.containsKey(keyId)) {
        _cardKeys[keyId] = GlobalKey();
      }
    }
  }

  RestaurantModel? get _restaurant => _db.restaurant;

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
    final list = _db.tables.map((t) => t.floor.trim()).where((f) => f.isNotEmpty).toSet().toList();
    list.sort();
    return ['All', ...list];
  }

  List<TableModel> get _filteredTables {
    var list = _db.tables;
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
        // On web, share / download
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

      final shareText = '🍽️ ${_restaurant?.name ?? "Restaurant"} - ${table.name} ($tCode)\n'
          'Scan to view our digital menu and order directly from your table:\n$directUrl';

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
            // 1. TOP HERO CARD: LIVE STOREFRONT & TABLE ORDERING INFO
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0052FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0052FF), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _restaurant?.name ?? 'Restaurant Table Ordering',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      'When customers scan any table QR, the menu opens instantly with the dining table pre-selected.',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    'https://apnaposs.vercel.app/$_companySlug/R=$_restaurantCode&T={T01..T${_db.tables.length.toString().padLeft(2, '0')}}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
                    hintText: 'Search by table name or number...',
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark),
                  onChanged: (val) {
                    if (val != null) setState(() => _currentTheme = val);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: TableStandTheme.modernClean,
                      child: Text('Modern Clean Stand'),
                    ),
                    DropdownMenuItem(
                      value: TableStandTheme.midnightDark,
                      child: Text('Midnight Dark Stand'),
                    ),
                    DropdownMenuItem(
                      value: TableStandTheme.warmWood,
                      child: Text('Warm Wood Stand'),
                    ),
                    DropdownMenuItem(
                      value: TableStandTheme.acrylicMinimal,
                      child: Text('Acrylic Minimalist'),
                    ),
                  ],
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
                  label: Text(floor == 'All' ? 'All Tables (${_db.tables.length})' : floor),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFloor = floor),
                  selectedColor: const Color(0xFF0052FF).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF0052FF),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
                          fontWeight: FontWeight.w600,
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

                // Action buttons: Download, Share, Print
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadTableQrImage(table),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF051C48),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
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
                        label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
    // Theme colors for physical stand
    Color standBg;
    Color standHeaderColor;
    Color qrBorderColor;
    Color standTextColor;
    Color standSubtextColor;
    Color badgeBg;
    Color badgeTextColor;

    switch (_currentTheme) {
      case TableStandTheme.midnightDark:
        standBg = const Color(0xFF0A1128);
        standHeaderColor = Colors.white;
        qrBorderColor = const Color(0xFFFFB703);
        standTextColor = Colors.white;
        standSubtextColor = const Color(0xFF94A3B8);
        badgeBg = const Color(0xFFFFB703);
        badgeTextColor = const Color(0xFF0A1128);
        break;
      case TableStandTheme.warmWood:
        standBg = const Color(0xFFFDFBF7);
        standHeaderColor = const Color(0xFF3E2723);
        qrBorderColor = const Color(0xFF8D6E63);
        standTextColor = const Color(0xFF3E2723);
        standSubtextColor = const Color(0xFF5D4037);
        badgeBg = const Color(0xFF4E342E);
        badgeTextColor = Colors.white;
        break;
      case TableStandTheme.acrylicMinimal:
        standBg = Colors.white;
        standHeaderColor = Colors.black;
        qrBorderColor = const Color(0xFFE2E8F0);
        standTextColor = Colors.black;
        standSubtextColor = const Color(0xFF64748B);
        badgeBg = Colors.black;
        badgeTextColor = Colors.white;
        break;
      case TableStandTheme.modernClean:
        standBg = Colors.white;
        standHeaderColor = const Color(0xFF051C48);
        qrBorderColor = const Color(0xFF0052FF);
        standTextColor = const Color(0xFF0F172A);
        standSubtextColor = const Color(0xFF475569);
        badgeBg = const Color(0xFF0052FF);
        badgeTextColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: standBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Restaurant Name
          Text(
            _restaurant?.name.toUpperCase() ?? 'RESTAURANT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: standHeaderColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Table Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${table.name.toUpperCase()} ($tCode)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: badgeTextColor,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Scannable QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: qrBorderColor.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: directUrl,
              version: QrVersions.auto,
              size: 160,
              gapless: true,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _currentTheme == TableStandTheme.midnightDark
                    ? const Color(0xFF0A1128)
                    : const Color(0xFF051C48),
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _currentTheme == TableStandTheme.midnightDark
                    ? const Color(0xFF0A1128)
                    : const Color(0xFF051C48),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Scan to Order Callout
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 16, color: qrBorderColor),
              const SizedBox(width: 6),
              Text(
                'SCAN TO VIEW MENU & ORDER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: standTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Point your phone camera or Google Lens to order directly to this table',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: standSubtextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Apna POS Digital Ordering',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: standSubtextColor,
                ),
              ),
            ],
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
