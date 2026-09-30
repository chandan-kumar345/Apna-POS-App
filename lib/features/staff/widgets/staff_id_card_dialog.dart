import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/services/bluetooth_printer_service.dart';
import '../../../core/services/windows_printer_service.dart';
import '../../../core/widgets/printer_selection_dialog.dart';

class StaffIdCardDialog extends StatefulWidget {
  final StaffModel staff;

  const StaffIdCardDialog({
    super.key,
    required this.staff,
  });

  static Future<void> show(BuildContext context, StaffModel staff) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StaffIdCardDialog(staff: staff),
    );
  }

  @override
  State<StaffIdCardDialog> createState() => _StaffIdCardDialogState();
}

class _StaffIdCardDialogState extends State<StaffIdCardDialog> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isPrinting = false;

  Future<Uint8List?> _captureCardImage() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // High-resolution capture for crystal sharp thermal printing
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[StaffIdCardDialog] Error capturing card widget: $e');
      return null;
    }
  }

  Future<void> _handlePrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final Uint8List? cardRaster = await _captureCardImage();

      final printerService = BluetoothPrinterService();
      final windowsPrinterService = WindowsPrinterService();
      final dbInstance = DatabaseService();
      final rest = dbInstance.restaurant;
      final currentUser = dbInstance.currentUser;

      // 1. Windows Native Printing Flow
      if (!kIsWeb && Platform.isWindows) {
        final defaultPrinter = await windowsPrinterService.getActiveDefaultPrinter();
        if (defaultPrinter != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Printing ID Card for ${widget.staff.name} on ${defaultPrinter.name}...'),
                backgroundColor: const Color(0xFF051C48),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          final success = await printerService.printStaffIdCard(
            staff: widget.staff,
            restaurant: rest,
            user: currentUser,
            cardRasterBytes: cardRaster,
            windowsPrinter: defaultPrinter,
          );
          if (!mounted) return;
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Staff ID Card for ${widget.staff.name} printed successfully!'),
                backgroundColor: const Color(0xFF16A34A),
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            PrinterSelectionDialog.show(context, staffToPrint: widget.staff);
          }
          return;
        }

        if (mounted) {
          PrinterSelectionDialog.show(context, staffToPrint: widget.staff);
        }
        return;
      }

      // 2. Mobile Android / iOS Bluetooth Flow
      bool isConn = await printerService.isConnected();
      if (!isConn) {
        isConn = await printerService.autoConnectSavedPrinter();
      }

      if (isConn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Printing Staff ID Card for ${widget.staff.name}...'),
              backgroundColor: const Color(0xFF051C48),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        final success = await printerService.printStaffIdCard(
          staff: widget.staff,
          restaurant: rest,
          user: currentUser,
          cardRasterBytes: cardRaster,
        );
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staff ID Card for ${widget.staff.name} printed successfully!'),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          PrinterSelectionDialog.show(context, staffToPrint: widget.staff);
        }
        return;
      }

      // Not connected -> Open Printer Selection dialog
      if (mounted) {
        PrinterSelectionDialog.show(context, staffToPrint: widget.staff);
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final db = DatabaseService();
    final restaurant = db.restaurant;
    final restaurantName = (restaurant?.name.isNotEmpty == true)
        ? restaurant!.name
        : (db.currentUser?.companyName?.isNotEmpty == true ? db.currentUser!.companyName! : 'Apna POS Store');
    final restaurantTagline = (restaurant?.tagline.isNotEmpty == true) ? restaurant!.tagline : 'Authentic Flavors & Swift Service';
    final companyLogoPath = db.companyLogoPath;

    final department = staff.department.isNotEmpty
        ? staff.department
        : (staff.role.toLowerCase().contains('cash')
            ? 'Front Office'
            : (staff.role.toLowerCase().contains('chef') || staff.role.toLowerCase().contains('kitchen')
                ? 'Kitchen Section'
                : (staff.role.toLowerCase().contains('waiter') || staff.role.toLowerCase().contains('cap')
                    ? 'Dining & Service'
                    : (staff.role.toLowerCase().contains('admin') || staff.role.toLowerCase().contains('owner') ? 'Management' : 'Operations'))));

    final empId = staff.employeeId.isNotEmpty
        ? staff.employeeId
        : (staff.id.length >= 4 ? 'EMP${staff.id.substring(0, 4).toUpperCase()}' : staff.id);

    final phone = staff.phone.isNotEmpty ? staff.phone : (restaurant?.phone.isNotEmpty == true ? restaurant!.phone : (db.currentUser?.phone ?? ''));
    final email = staff.email.isNotEmpty
        ? staff.email
        : (db.currentUser?.email.isNotEmpty == true
            ? db.currentUser!.email
            : '${staff.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@${restaurantName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}.com');

    final joinDateStr = staff.joiningDate != null
        ? DateFormat('dd MMM yyyy').format(staff.joiningDate!)
        : DateFormat('dd MMM yyyy').format(staff.createdAt);

    final qrPayload = 'STAFF-ID:$empId|NAME:${staff.name}|ROLE:${staff.role}|DEPT:$department|ORG:$restaurantName';

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 6),
      surfaceTintColor: Colors.transparent,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 350),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrollable ID Card Visual Container with ultra-compact paddings
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lanyard Ribbon Strap & Metallic Clip (Compact)
                      _buildLanyardClip(),

                      // Physical ID Card Body wrapped in RepaintBoundary for exact pixel print
                      RepaintBoundary(
                        key: _cardKey,
                        child: Container(
                          width: 310,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x180F172A),
                                blurRadius: 14,
                                offset: Offset(0, 5),
                              ),
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              children: [
                                // Decorative Background Top Wave Curves
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _IdCardWavePainter(),
                                  ),
                                ),

                                // Background Logo Watermark with High Readability Opacity (0.075)
                                _buildWatermarkLogo(companyLogoPath),

                                // Card Content Column
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Top Punch Hole Slot
                                    const SizedBox(height: 5),
                                    Container(
                                      width: 30,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCBD5E1),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Top Section: Left Side Extra-Large Logo (68px) & Right Side Company Name
                                    _buildBrandHeader(restaurantName, companyLogoPath),
                                    const SizedBox(height: 8),

                                    // Staff Avatar Photo
                                    _buildStaffAvatar(staff),
                                    const SizedBox(height: 6),

                                    // Staff Name (Bold & Crisp with Title Case)
                                    Text(
                                      _toTitleCase(staff.name),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: 0.1,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),

                                    // Spaced Role Badge Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: staff.roleBgColor,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        staff.role.toUpperCase().split('').join(' '),
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: staff.roleTextColor,
                                          letterSpacing: 1.8,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 7),

                                    // Professional Structured Key-Value Details Container (Like Real ID Cards)
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 14),
                                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.88),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          _buildInfoRow(
                                            icon: Icons.badge_outlined,
                                            label: 'Employee ID',
                                            value: empId,
                                          ),
                                          _buildInfoRow(
                                            icon: Icons.apartment_outlined,
                                            label: 'Department',
                                            value: department,
                                          ),
                                          _buildInfoRow(
                                            icon: Icons.work_outline_rounded,
                                            label: 'Role',
                                            value: _toTitleCase(staff.role),
                                          ),
                                          _buildInfoRow(
                                            icon: Icons.phone_outlined,
                                            label: 'Phone',
                                            value: phone,
                                          ),
                                          _buildInfoRow(
                                            icon: Icons.mail_outline_rounded,
                                            label: 'Email',
                                            value: email,
                                          ),
                                          _buildInfoRow(
                                            icon: Icons.calendar_today_outlined,
                                            label: 'Date of Joining',
                                            value: joinDateStr,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Bottom Dark Navy Footer with Deep Wave Design & QR Code
                                    _buildBottomWaveFooter(
                                      restaurantName: restaurantName,
                                      tagline: restaurantTagline,
                                      qrData: qrPayload,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions Row (Close & Print Buttons) - Compact
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                ),
                child: Row(
                  children: [
                    // Close Button
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 15),
                        label: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
                          padding: const EdgeInsets.symmetric(vertical: 8.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Print ID Card Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isPrinting ? null : _handlePrint,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_rounded, size: 15, color: Colors.white),
                        label: Text(
                          _isPrinting ? 'Printing...' : 'Print ID Card',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 1.5,
                          padding: const EdgeInsets.symmetric(vertical: 8.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          shadowColor: const Color(0x402563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Low Opacity Watermark of Company Logo in Card Background
  Widget _buildWatermarkLogo(String? photoPath) {
    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: 0.075,
          child: SizedBox(
            width: 200,
            height: 200,
            child: _buildCompanyLogoImage(photoPath, 200, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // Profile Main Logo Image Builder
  Widget _buildCompanyLogoImage(String? photoPath, double size, {BoxFit fit = BoxFit.contain, Color? fallbackTextColor}) {
    if (photoPath != null && photoPath.isNotEmpty) {
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        return Image.network(
          photoPath,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit, fallbackTextColor: fallbackTextColor),
        );
      } else if (photoPath.startsWith('assets/')) {
        return Image.asset(
          photoPath,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit, fallbackTextColor: fallbackTextColor),
        );
      } else if (!photoPath.contains('_selected') && File(photoPath).existsSync()) {
        return Image.file(
          File(photoPath),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit, fallbackTextColor: fallbackTextColor),
        );
      } else if (photoPath.startsWith('data:image') || (photoPath.length > 50 && !photoPath.startsWith('/'))) {
        try {
          final cleanBase64 = photoPath.contains(',') ? photoPath.split(',').last : photoPath;
          final bytes = base64Decode(cleanBase64.trim());
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit, fallbackTextColor: fallbackTextColor),
          );
        } catch (_) {}
      }
    }

    return _buildDefaultCompanyLogo(size, fit: fit, fallbackTextColor: fallbackTextColor);
  }

  Widget _buildDefaultCompanyLogo(double size, {BoxFit fit = BoxFit.contain, Color? fallbackTextColor}) {
    return Image.asset(
      'assets/images/restaurant_icon.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildCompanyFallbackInitial(size, fallbackTextColor: fallbackTextColor),
      ),
    );
  }

  Widget _buildCompanyFallbackInitial(double size, {Color? fallbackTextColor}) {
    final db = DatabaseService();
    final companyName = db.restaurant?.name ?? db.currentUser?.companyName ?? 'Apna POS';
    String initial = 'A';
    if (companyName.trim().isNotEmpty) {
      initial = companyName.trim()[0].toUpperCase();
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w900,
          color: fallbackTextColor ?? Colors.white,
        ),
      ),
    );
  }

  // Lanyard Neck Ribbon and Metallic Clasp Graphic (Compact)
  Widget _buildLanyardClip() {
    return Column(
      children: [
        // Blue Fabric Lanyard Strap
        Container(
          width: 24,
          height: 12,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
            boxShadow: [
              BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 12,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0x33FFFFFF), width: 1),
                  right: BorderSide(color: Color(0x33FFFFFF), width: 1),
                ),
              ),
            ),
          ),
        ),

        // Metallic Silver Badge Clip
        Container(
          width: 30,
          height: 11,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFCBD5E1), Color(0xFFF1F5F9), Color(0xFF94A3B8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(3.5),
            border: Border.all(color: const Color(0xFF94A3B8), width: 0.8),
            boxShadow: const [
              BoxShadow(color: Color(0x24000000), blurRadius: 2.5, offset: Offset(0, 1)),
            ],
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(1.8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Top Section: Left Side Extra-Large Logo (68px) & Right Side Company Name
  Widget _buildBrandHeader(String restaurantName, String? logoPath) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Extra-Large Main Profile Logo (68×68)
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.8),
              boxShadow: const [
                BoxShadow(color: Color(0x1E000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: ClipOval(
              child: _buildCompanyLogoImage(logoPath, 60, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),

          // Right Side: Company Name & Subtitle (Right Aligned & Bold)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restaurantName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF991B1B), // Signature Crimson Brand Color
                    letterSpacing: 0.8,
                    height: 1.15,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'R E S T A U R A N T',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                    letterSpacing: 2.2,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Circular Staff Avatar
  Widget _buildStaffAvatar(StaffModel staff) {
    const double size = 72;
    Widget avatarContent;

    String effectivePhoto = staff.avatarUrl.trim();
    if (effectivePhoto.isEmpty) {
      final db = DatabaseService();
      if (db.currentUser != null && (db.currentUser!.id == staff.id || db.currentUser!.employeeId == staff.employeeId)) {
        effectivePhoto = db.currentUser!.profilePhotoPath?.trim() ?? '';
      }
    }

    if (effectivePhoto.isNotEmpty) {
      if (effectivePhoto.startsWith('http://') || effectivePhoto.startsWith('https://')) {
        avatarContent = Image.network(
          effectivePhoto,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(staff, size),
        );
      } else if (effectivePhoto.startsWith('data:image') || (effectivePhoto.length > 50 && !effectivePhoto.startsWith('/'))) {
        try {
          final cleanBase64 = effectivePhoto.contains(',') ? effectivePhoto.split(',').last : effectivePhoto;
          final bytes = base64Decode(cleanBase64.trim());
          avatarContent = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(staff, size),
          );
        } catch (_) {
          avatarContent = _buildInitialsAvatar(staff, size);
        }
      } else if (effectivePhoto.startsWith('assets/')) {
        avatarContent = Image.asset(
          effectivePhoto,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(staff, size),
        );
      } else if (!effectivePhoto.contains('_selected') && File(effectivePhoto).existsSync()) {
        avatarContent = Image.file(
          File(effectivePhoto),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(staff, size),
        );
      } else {
        avatarContent = _buildInitialsAvatar(staff, size);
      }
    } else {
      avatarContent = _buildInitialsAvatar(staff, size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );
  }

  Widget _buildInitialsAvatar(StaffModel staff, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A),
            staff.roleTextColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          staff.initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text;
    return text.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  // Professional 2-Column Key-Value Row with Straight Alignment (Like Real ID Cards)
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.1,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Dark Navy Bottom Footer with Pronounced Deep Flowing Waves
  Widget _buildBottomWaveFooter({
    required String restaurantName,
    required String tagline,
    required String qrData,
  }) {
    return Stack(
      children: [
        // Layered Wave Painter Background with pronounced peaks & valleys
        Positioned.fill(
          child: CustomPaint(
            painter: _FooterWavePainter(),
          ),
        ),

        // Footer Content
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // QR Code in White Rounded Badge
              Container(
                padding: const EdgeInsets.all(3.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 40.0,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),

              // Vertical Thin Separator Line
              Container(
                width: 1,
                height: 36,
                color: const Color(0x33FFFFFF),
              ),
              const SizedBox(width: 10),

              // Restaurant Title & Tagline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      restaurantName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'R E S T A U R A N T',
                      style: TextStyle(
                        fontSize: 6.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: const TextStyle(
                        fontSize: 6.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60A5FA),
                        letterSpacing: 1.1,
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
      ],
    );
  }
}

// Custom Painter for bottom pronounced flowing footer waves (Deep blue wave + dark navy wave)
class _FooterWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Royal Blue Dynamic Wave Accent Layer with pronounced wave curves
    final accentPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final accentPath = Path();
    accentPath.moveTo(0, 13);
    accentPath.cubicTo(
      size.width * 0.22, -6,
      size.width * 0.58, 24,
      size.width, 2,
    );
    accentPath.lineTo(size.width, size.height);
    accentPath.lineTo(0, size.height);
    accentPath.close();
    canvas.drawPath(accentPath, accentPaint);

    // 2. Dark Navy Main Footer with pronounced matching wave curve
    final navyPaint = Paint()
      ..color = const Color(0xFF0D223A)
      ..style = PaintingStyle.fill;

    final navyPath = Path();
    navyPath.moveTo(0, 20);
    navyPath.cubicTo(
      size.width * 0.24, 2,
      size.width * 0.60, 30,
      size.width, 8,
    );
    navyPath.lineTo(size.width, size.height);
    navyPath.lineTo(0, size.height);
    navyPath.close();
    canvas.drawPath(navyPath, navyPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for top layered decorative wave curves
class _IdCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top Left Royal Blue Curve
    final paint1 = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, 0);
    path1.lineTo(size.width * 0.45, 0);
    path1.cubicTo(size.width * 0.35, size.height * 0.12, 0, size.height * 0.18, 0, size.height * 0.24);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Top Right Navy Blue Curve
    final paint2 = Paint()
      ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(size.width, 0);
    path2.lineTo(size.width * 0.55, 0);
    path2.cubicTo(size.width * 0.65, size.height * 0.10, size.width, size.height * 0.16, size.width, size.height * 0.22);
    path2.close();
    canvas.drawPath(path2, paint2);

    // Subtle background watermark curved POS lines
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = 0; i < 4; i++) {
      final linePath = Path();
      linePath.moveTo(0, size.height * 0.20 + (i * 18));
      linePath.cubicTo(
        size.width * 0.3,
        size.height * 0.26 + (i * 18),
        size.width * 0.7,
        size.height * 0.16 + (i * 18),
        size.width,
        size.height * 0.22 + (i * 18),
      );
      canvas.drawPath(linePath, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
