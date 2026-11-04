import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/models/table_model.dart';
import '../../core/network/api_endpoints.dart';
import '../storefront/screens/customer_storefront_screen.dart';

/// Table Stand Themes for Designer QR Stand Printing (Matching Reference UI)
enum TableStandTheme {
  midnightCharcoal,
  oceanSapphire,
  goldenAmber,
  royalEmerald,
  crimsonRuby,
}

class StandThemeConfig {
  final String label;
  final String subtitle;
  final List<Color> backgroundGradient;
  final List<Color> buttonGradient;
  final Color qrEyeColor;
  final Color qrDataColor;
  final Color accentPillBg;
  final Color accentPillText;

  const StandThemeConfig({
    required this.label,
    required this.subtitle,
    required this.backgroundGradient,
    required this.buttonGradient,
    required this.qrEyeColor,
    required this.qrDataColor,
    required this.accentPillBg,
    required this.accentPillText,
  });
}

/// Curated restaurant ambiance background presets for standees
class StandeeBackgroundPreset {
  final String id;
  final String name;
  final String description;
  final String imageUrl;

  const StandeeBackgroundPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
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
  final Map<String, Uint8List> _base64Cache = {};

  static const String _prefStandeeBgKey = 'table_qr_standee_custom_bg_v1';

  TableStandTheme _currentTheme = TableStandTheme.oceanSapphire;
  String _selectedFloor = 'All';
  String _searchQuery = '';
  bool _isDownloadingAll = false;
  final String _restaurantCode = 'R1';

  /// Active custom background image across ALL table standees (URL, local path, or null)
  String? _customStandeeBg;

  // Curated high-resolution restaurant ambiance presets (Matching Image 3)
  static const List<StandeeBackgroundPreset> _ambiancePresets = [
    StandeeBackgroundPreset(
      id: 'cozy_bistro',
      name: 'Cozy Bistro & Cafe',
      description: 'Warm cafe ambiance with pendant lights & wooden tables',
      imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800&q=80',
    ),
    StandeeBackgroundPreset(
      id: 'fine_dining',
      name: 'Fine Dining Room',
      description: 'Elegant restaurant dining hall with subtle warm lighting',
      imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80',
    ),
    StandeeBackgroundPreset(
      id: 'rustic_steakhouse',
      name: 'Rustic Wood Lounge',
      description: 'Warm dark wood & exposed brick steakhouse aesthetic',
      imageUrl: 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=800&q=80',
    ),
    StandeeBackgroundPreset(
      id: 'modern_lounge',
      name: 'Modern Bar & Lounge',
      description: 'Chic contemporary restaurant with neon and ambient glow',
      imageUrl: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800&q=80',
    ),
    StandeeBackgroundPreset(
      id: 'trattoria',
      name: 'Italian Trattoria',
      description: 'Authentic pizzeria and trattoria dining room ambiance',
      imageUrl: 'https://images.unsplash.com/photo-1537047902294-62a40c20a6ae?w=800&q=80',
    ),
  ];

  // Neumorphic Theme Constants (Matching POS Register & Business Hub)
  static const Color _bgCanvas = Color(0xFFEEF2F6);
  static const Color _surface = Color(0xFFEEF2F6);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _blueBrand = Color(0xFF0052FF);
  static const Color _navyBrand = Color(0xFF051C48);

  static List<BoxShadow> get _neumorphicRaised => [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.95),
          offset: const Offset(-4, -4),
          blurRadius: 10,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0xFFC5D1E0).withValues(alpha: 0.7),
          offset: const Offset(4, 4),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get _neumorphicSunken => [
        BoxShadow(
          color: const Color(0xFFC5D1E0).withValues(alpha: 0.6),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.8),
          offset: const Offset(-2, -2),
          blurRadius: 4,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _initKeys();
    _loadSavedBackground();
  }

  Future<void> _loadSavedBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefStandeeBgKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _customStandeeBg = saved);
      }
    } catch (e) {
      debugPrint('[TableQrDownloadScreen] Failed to load saved background: $e');
    }
  }

  Future<void> _updateStandeeBackground(String? pathOrUrl) async {
    setState(() => _customStandeeBg = pathOrUrl);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pathOrUrl == null || pathOrUrl.isEmpty) {
        await prefs.remove(_prefStandeeBgKey);
      } else {
        await prefs.setString(_prefStandeeBgKey, pathOrUrl);
      }
    } catch (e) {
      debugPrint('[TableQrDownloadScreen] Failed to save background: $e');
    }
  }

  RestaurantModel? get _restaurant => _db.restaurant;

  String get _restaurantName {
    final restName = _restaurant?.name.trim() ?? '';
    if (restName.isNotEmpty) return restName;
    final compName = _db.currentUser?.companyName?.trim() ?? '';
    if (compName.isNotEmpty) return compName;
    final userName = _db.currentUser?.name.trim() ?? '';
    if (userName.isNotEmpty) return userName;
    return 'Apna POS';
  }

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
      case TableStandTheme.midnightCharcoal:
        return const StandThemeConfig(
          label: 'Midnight Onyx & Slate',
          subtitle: 'Deep charcoal slate with electric cyan accents',
          backgroundGradient: [Color(0xFF181B20), Color(0xFF23272F)],
          buttonGradient: [Color(0xFF0284C7), Color(0xFF06B6D4)],
          qrEyeColor: Color(0xFF0F172A),
          qrDataColor: Color(0xFF1E293B),
          accentPillBg: Color(0xFFE0F2FE),
          accentPillText: Color(0xFF0284C7),
        );
      case TableStandTheme.oceanSapphire:
        return const StandThemeConfig(
          label: 'Ocean Sapphire Blue',
          subtitle: 'Cobalt deep ocean with bright cyan highlights',
          backgroundGradient: [Color(0xFF0B2545), Color(0xFF134074)],
          buttonGradient: [Color(0xFF0052FF), Color(0xFF38BDF8)],
          qrEyeColor: Color(0xFF0B2545),
          qrDataColor: Color(0xFF134074),
          accentPillBg: Color(0xFFEFF6FF),
          accentPillText: Color(0xFF1D4ED8),
        );
      case TableStandTheme.goldenAmber:
        return const StandThemeConfig(
          label: 'Golden Amber & Honey',
          subtitle: 'Rich warm sunburst amber and gold',
          backgroundGradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
          buttonGradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
          qrEyeColor: Color(0xFF78350F),
          qrDataColor: Color(0xFF451A03),
          accentPillBg: Color(0xFFFFFBEB),
          accentPillText: Color(0xFFB45309),
        );
      case TableStandTheme.royalEmerald:
        return const StandThemeConfig(
          label: 'Royal Emerald & Mint',
          subtitle: 'Deep forest emerald with fresh mint accents',
          backgroundGradient: [Color(0xFF064E3B), Color(0xFF047857)],
          buttonGradient: [Color(0xFF059669), Color(0xFF10B981)],
          qrEyeColor: Color(0xFF064E3B),
          qrDataColor: Color(0xFF064E3B),
          accentPillBg: Color(0xFFECFDF5),
          accentPillText: Color(0xFF047857),
        );
      case TableStandTheme.crimsonRuby:
        return const StandThemeConfig(
          label: 'Crimson Ruby Wine',
          subtitle: 'Luxurious ruby wine with warm gold accents',
          backgroundGradient: [Color(0xFF881337), Color(0xFFBE123C)],
          buttonGradient: [Color(0xFFBE123C), Color(0xFFF43F5E)],
          qrEyeColor: Color(0xFF881337),
          qrDataColor: Color(0xFF4C0519),
          accentPillBg: Color(0xFFFFF1F2),
          accentPillText: Color(0xFFBE123C),
        );
    }
  }

  /// Authoritative dynamic logo resolution across all database fallbacks
  String _resolveEffectiveLogo() {
    final compLogo = _db.companyLogoPath?.trim();
    final restLogo = _db.restaurant?.logoUrl?.trim();
    final userLogo = _db.currentUser?.profilePhotoPath?.trim();
    final ownerLogo = _db.cachedOwnerUser?.profilePhotoPath?.trim();

    if (compLogo != null && compLogo.isNotEmpty && compLogo != 'assets/images/logo.png' && compLogo != 'none') {
      return compLogo;
    }
    if (restLogo != null && restLogo.isNotEmpty && restLogo != 'assets/images/logo.png' && restLogo != 'none') {
      return restLogo;
    }
    if (userLogo != null && userLogo.isNotEmpty && userLogo != 'assets/images/logo.png' && userLogo != 'none') {
      return userLogo;
    }
    if (ownerLogo != null && ownerLogo.isNotEmpty && ownerLogo != 'assets/images/logo.png' && ownerLogo != 'none') {
      return ownerLogo;
    }
    return '';
  }

  /// Profile logo resolver with dynamic database sources, Base64, network URL,
  /// local file, assets, and monogram fallback
  Widget _buildProfileLogoWidget({
    required double size,
    required Color borderColor,
    double borderWidth = 2.0,
    bool isCircular = true,
  }) {
    final effectiveLogo = _resolveEffectiveLogo();
    final displayName = _restaurantName;
    final initial = displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : 'P';

    Widget buildInitialFallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircular ? null : BorderRadius.circular(size * 0.22),
          gradient: const LinearGradient(
            colors: [Color(0xFF0052FF), Color(0xFF051C48)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
    }

    Widget imageContent;

    if (effectiveLogo.isEmpty) {
      imageContent = buildInitialFallback();
    } else {
      final trimmed = effectiveLogo;

      // 1. Base64 / Data URI image
      if (trimmed.startsWith('data:image') ||
          trimmed.startsWith('data:') ||
          (trimmed.length > 80 && !trimmed.startsWith('/') && !trimmed.startsWith('assets') && !trimmed.startsWith('http'))) {
        try {
          Uint8List? bytes = _base64Cache[trimmed];
          if (bytes == null) {
            final commaIdx = trimmed.indexOf(',');
            final clean = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
            bytes = base64Decode(clean.replaceAll('\n', '').replaceAll('\r', '').trim());
            _base64Cache[trimmed] = bytes;
          }
          imageContent = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
          );
        } catch (_) {
          imageContent = buildInitialFallback();
        }
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        // 2. HTTP / HTTPS Network image
        final resolvedUrl = ApiEndpoints.resolveMediaUrl(trimmed);
        imageContent = Image.network(
          resolvedUrl.isNotEmpty ? resolvedUrl : trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
        );
      } else if (trimmed.startsWith('assets/')) {
        // 3. Asset Image
        imageContent = Image.asset(
          trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
        );
      } else {
        // 4. File on disk / Relative path resolved via ApiEndpoints
        if (!kIsWeb) {
          try {
            final f = File(trimmed);
            if (f.existsSync()) {
              imageContent = Image.file(
                f,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
              );
            } else {
              final resolved = ApiEndpoints.resolveMediaUrl(trimmed);
              if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
                imageContent = Image.network(
                  resolved,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
                );
              } else {
                imageContent = buildInitialFallback();
              }
            }
          } catch (_) {
            imageContent = buildInitialFallback();
          }
        } else {
          final resolved = ApiEndpoints.resolveMediaUrl(trimmed);
          if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
            imageContent = Image.network(
              resolved,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
            );
          } else {
            imageContent = buildInitialFallback();
          }
        }
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(size * 0.22),
        border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
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
        borderRadius: isCircular ? BorderRadius.circular(size) : BorderRadius.circular(size * 0.22),
        child: imageContent,
      ),
    );
  }

  /// Standee background renderer supporting custom image / preset image / gradient fallback
  Widget _buildStandeeBackground(StandThemeConfig cfg) {
    if (_customStandeeBg != null && _customStandeeBg!.trim().isNotEmpty) {
      final bg = _customStandeeBg!.trim();
      Widget img;
      if (bg.startsWith('http://') || bg.startsWith('https://')) {
        img = Image.network(
          bg,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildGradientFallback(cfg),
        );
      } else if (bg.startsWith('data:image') || bg.startsWith('data:')) {
        try {
          final commaIdx = bg.indexOf(',');
          final clean = commaIdx != -1 ? bg.substring(commaIdx + 1) : bg;
          final bytes = base64Decode(clean.replaceAll('\n', '').replaceAll('\r', '').trim());
          img = Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGradientFallback(cfg),
          );
        } catch (_) {
          img = _buildGradientFallback(cfg);
        }
      } else if (bg.startsWith('assets/')) {
        img = Image.asset(
          bg,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildGradientFallback(cfg),
        );
      } else if (!kIsWeb) {
        final f = File(bg);
        if (f.existsSync()) {
          img = Image.file(
            f,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGradientFallback(cfg),
          );
        } else {
          img = _buildGradientFallback(cfg);
        }
      } else {
        img = _buildGradientFallback(cfg);
      }

      return SizedBox.expand(child: img);
    }

    return _buildGradientFallback(cfg);
  }

  Widget _buildGradientFallback(StandThemeConfig cfg) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cfg.backgroundGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
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
      final fileName = 'Table_${tCode}_Standee_QR.png';

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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () => SharePlus.instance.share(ShareParams(
                  files: [XFile(file.path)],
                  text: 'Scan to order at $_restaurantName - ${table.name}',
                )),
              ),
            ),
          );
        }
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
          text: 'Table $tCode QR Standee - $_restaurantName',
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

      final shareText = '🍽️ $_restaurantName - ${table.name} ($tCode)\n'
          'Scan our table QR to view our digital menu and order directly from your table:\n$directUrl';

      if (bytes != null && !kIsWeb) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Table_${tCode}_Standee.png');
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
            final fileName = 'Table_${tCode}_Standee.png';
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
                    'Downloaded $successCount Table QR standees successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: _blueBrand,
            behavior: SnackBarBehavior.floating,
            action: filesToShare.isNotEmpty
                ? SnackBarAction(
                    label: 'Share All',
                    textColor: Colors.white,
                    onPressed: () => SharePlus.instance.share(ShareParams(
                      files: filesToShare,
                      text: 'All Table QR Stands - $_restaurantName',
                    )),
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
        content: Text('Copied $label to clipboard'),
        backgroundColor: _navyBrand,
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.table_restaurant_rounded, color: _blueBrand),
            SizedBox(width: 10),
            Text('Configure Active Tables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the total number of dining tables available at your outlet. Only tables up to this count will be generated and accessible by customers.',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Total Tables',
                hintText: 'e.g. 20',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blueBrand, width: 2)),
                prefixIcon: const Icon(Icons.pin_rounded, color: _blueBrand),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600)),
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
              backgroundColor: _blueBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Save Count', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Bottom Sheet to customize Standee Background Image across ALL Table QRs
  void _showBackgroundSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title and Close Button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.wallpaper_rounded, color: _blueBrand, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Standee Background Image',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Changes background across all table standees',
                            style: TextStyle(fontSize: 12, color: _textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Device Gallery / Camera & Reset Buttons
                Row(
                  children: [
                    // Upload from Device
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final picker = ImagePicker();
                            final XFile? picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1200,
                              maxHeight: 1600,
                              imageQuality: 88,
                            );
                            if (picked != null) {
                              await _updateStandeeBackground(picked.path);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Custom background applied to all table standees!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('[TableQrDownloadScreen] Pick image error: $e');
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                        label: const Text('Pick from Gallery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navyBrand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Reset to Theme Gradient
                    OutlinedButton.icon(
                      onPressed: _customStandeeBg == null
                          ? null
                          : () async {
                              await _updateStandeeBackground(null);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reset to theme gradient!'),
                                    backgroundColor: _navyBrand,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: BorderSide(
                          color: _customStandeeBg == null ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  'OR CHOOSE CURATED RESTAURANT AMBIANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // Curated Presets Grid
                Expanded(
                  child: ListView.separated(
                    itemCount: _ambiancePresets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final preset = _ambiancePresets[idx];
                      final isSelected = _customStandeeBg == preset.imageUrl;

                      return InkWell(
                        onTap: () async {
                          await _updateStandeeBackground(preset.imageUrl);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Applied "${preset.name}" background to all standees!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? _blueBrand : const Color(0xFFE2E8F0),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Preset Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Image.network(
                                    preset.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFF0F172A),
                                      child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            preset.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected ? _blueBrand : _textDark,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _blueBrand,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Active',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      preset.description,
                                      style: const TextStyle(fontSize: 11.5, color: _textMuted),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initKeys();

    return Scaffold(
      backgroundColor: _bgCanvas,
      // RESPONSIVE APPBAR MATCHING POS SCREEN (ZERO HORIZONTAL OVERFLOW)
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC5D1E0).withValues(alpha: 0.5),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Back Button with Soft Neumorphic Raised Effect
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _neumorphicRaised,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: _textDark, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Dynamic Restaurant Logo Emblem
                  _buildProfileLogoWidget(
                    size: 36,
                    borderColor: _blueBrand,
                    borderWidth: 1.5,
                    isCircular: true,
                  ),
                  const SizedBox(width: 8),

                  // Title & Table Count Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _restaurantName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _textDark,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Table QR Standees',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Compact Table Count Config Pill (Matching POS screen actions)
                  InkWell(
                    onTap: _showEditTableCountDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _neumorphicRaised,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.table_restaurant_rounded, size: 14, color: _navyBrand),
                          const SizedBox(width: 4),
                          Text(
                            '$_maxTableCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _navyBrand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Download All Button (Vibrant Blue Pill matching POS)
                  InkWell(
                    onTap: _isDownloadingAll ? null : _downloadAllTableQrs,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0052FF), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0052FF).withValues(alpha: 0.35),
                            offset: const Offset(0, 2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDownloadingAll)
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.download_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _isDownloadingAll ? 'Saving...' : 'Download All',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. NEUMORPHIC SEARCH & CONTROLS (FULL VISIBILITY OF OPTION TEXTS)
            _buildNeumorphicFilterAndThemeBar(),

            const SizedBox(height: 16),

            // 2. DESIGNER TABLE QR CARDS GRID (WITH CUSTOM BACKGROUND SUPPORT)
            if (_filteredTables.isEmpty)
              _buildEmptyState()
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
                        child: _buildDesignerTableCard(table),
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

  /// Neumorphic Filter and Theme Bar with full text visibility and background customization
  Widget _buildNeumorphicFilterAndThemeBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Width Sunken Search Bar (Never truncated)
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF5),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _neumorphicSunken,
            border: Border.all(color: const Color(0xFFD6E2F0), width: 1.0),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
            decoration: InputDecoration(
              hintText: 'Search table (e.g. 01, Table 5)...',
              hintStyle: const TextStyle(fontSize: 12.5, color: _textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: _textMuted),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Standee Options Row: Theme Dropdown + Standee Background Button
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 1. Standee Background Image Button (Applies across all QRs)
              InkWell(
                onTap: _showBackgroundSelectorModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _customStandeeBg != null ? const Color(0xFF0F2B48) : _surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _neumorphicRaised,
                    border: Border.all(
                      color: _customStandeeBg != null ? Colors.transparent : Colors.white,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wallpaper_rounded,
                        size: 16,
                        color: _customStandeeBg != null ? const Color(0xFF38BDF8) : _blueBrand,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _customStandeeBg != null ? 'Custom Background Active' : 'Standee Background',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _customStandeeBg != null ? Colors.white : _textDark,
                        ),
                      ),
                      if (_customStandeeBg != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _updateStandeeBackground(null),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 2. Stand Theme Selector Dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _neumorphicRaised,
                  border: Border.all(color: Colors.white, width: 1.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TableStandTheme>(
                    value: _currentTheme,
                    icon: const Icon(Icons.palette_rounded, size: 16, color: _blueBrand),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _textDark),
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
                                gradient: LinearGradient(colors: cfg.backgroundGradient),
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
        ),
        const SizedBox(height: 10),

        // Floor Filter Chips with Smooth Neumorphic Styling
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _floors.map((floor) {
              final isSelected = _selectedFloor == floor;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFloor = floor),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? _blueBrand : _surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _blueBrand.withValues(alpha: 0.4),
                                offset: const Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ]
                          : _neumorphicRaised,
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      floor == 'All' ? 'All Tables ($_maxTableCount)' : floor,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? Colors.white : _textDark,
                      ),
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

  /// Designer Table Card with removed link text and neat controls
  Widget _buildDesignerTableCard(TableModel table) {
    final keyId = 'table_${table.id}_${table.tableNumber}';
    final cardKey = _cardKeys.putIfAbsent(keyId, () => GlobalKey());
    final directUrl = _buildTableDirectUrl(table.tableNumber);
    final tCode = _formatTableCode(table.tableNumber);
    final cfg = _getThemeConfig(_currentTheme);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _neumorphicRaised,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. REPAINT BOUNDARY: STYLISH STAND CARD (WITH RESTAURANT BACKGROUND IMAGE)
          RepaintBoundary(
            key: cardKey,
            child: _buildDesignerStandWidget(table, tCode, directUrl, cfg),
          ),

          const SizedBox(height: 12),

          // 2. PRIMARY ACTION: DOWNLOAD QR STANDEE
          Container(
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cfg.buttonGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: cfg.buttonGradient.first.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _downloadTableQrImage(table),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, color: Colors.white, size: 17),
                      SizedBox(width: 8),
                      Text(
                        'Download QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. SECONDARY CONTROLS (Share, Preview, Copy Link)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _neumorphicRaised,
                  ),
                  child: TextButton.icon(
                    onPressed: () => _shareTableQr(table),
                    icon: const Icon(Icons.share_rounded, size: 14, color: _navyBrand),
                    label: const Text(
                      'Share',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _navyBrand),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _neumorphicRaised,
                  ),
                  child: TextButton.icon(
                    onPressed: () => _openStorefrontPreview(table),
                    icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF0D9488)),
                    label: const Text(
                      'Preview',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _neumorphicRaised,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.copy_rounded, size: 15, color: _blueBrand),
                  tooltip: 'Copy Direct Link',
                  onPressed: () => _copyToClipboard(directUrl, 'Table $tCode QR Link'),
                ),
              ),
            ],
          ),
          // Link text removed completely per user request
        ],
      ),
    );
  }

  /// Designer Standee Widget (Matching Image 3 layout with background photo support)
  Widget _buildDesignerStandWidget(
    TableModel table,
    String tCode,
    String directUrl,
    StandThemeConfig cfg,
  ) {
    final tableNumClean = table.tableNumber.toString().padLeft(2, '0');
    final floorLabel = table.floor.isNotEmpty && table.floor != 'Ground Floor' ? ' • ${table.floor}' : '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // 1. Standee Background: Curated Image or Theme Gradient
            Positioned.fill(
              child: _buildStandeeBackground(cfg),
            ),

            // 2. High-Contrast Dark Translucent Overlay (Ensures text & QR pop cleanly)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(
                  alpha: _customStandeeBg != null ? 0.42 : 0.0,
                ),
              ),
            ),

            // 3. Foreground Standee Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Capsule Badge: TABLE 01-A
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'TABLE $tableNumClean$floorLabel',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Circular Emblem with crisp white border ring
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildProfileLogoWidget(
                        size: 55,
                        borderColor: Colors.transparent,
                        borderWidth: 0,
                        isCircular: true,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Restaurant Name
                  Text(
                    _restaurantName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1.5)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14),

                  // Pure White Card Holding Sharp QR Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          data: directUrl,
                          version: QrVersions.auto,
                          size: 165,
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
                        // Branded micro logo badge in center of QR
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: _buildProfileLogoWidget(
                            size: 34,
                            borderColor: cfg.qrEyeColor,
                            borderWidth: 1.2,
                            isCircular: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SCAN FOR MENU
                  const Text(
                    'SCAN FOR MENU',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 1.5)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Powered by Apna POS
                  Text(
                    'Powered by Apna POS',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: Colors.white.withValues(alpha: 0.85),
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                      ],
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _neumorphicRaised,
      ),
      child: const Column(
        children: [
          Icon(Icons.table_restaurant_outlined, size: 48, color: _textMuted),
          SizedBox(height: 14),
          Text(
            'No Tables Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
          ),
          SizedBox(height: 6),
          Text(
            'Try adjusting your search query or floor filter.',
            style: TextStyle(fontSize: 13, color: _textMuted),
          ),
        ],
      ),
    );
  }
}
