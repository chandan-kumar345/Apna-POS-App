import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../widgets/staff_id_card_dialog.dart';

/// Redesigned Neumorphic Staff Profile Screen with Wrapped Responsive Layout
/// Cleaned of redundant action buttons & hint chips for a polished, modern Soft UI.
class StaffProfileScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onNavigateToDashboard;

  const StaffProfileScreen({
    super.key,
    this.onOpenDrawer,
    this.onNavigateToDashboard,
  });

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  StaffModel _getEffectiveStaff(DatabaseService db) {
    final user = db.currentUser;
    if (user == null) {
      if (db.staffList.isNotEmpty) return db.staffList.first;
      return StaffModel(
        id: '',
        name: '',
        employeeId: '',
        createdAt: DateTime.now(),
      );
    }

    // Try finding in db.staffList
    final match = db.staffList.where((s) =>
        (s.id.isNotEmpty && s.id == user.id) ||
        (s.employeeId.isNotEmpty && user.employeeId != null && s.employeeId == user.employeeId) ||
        (s.email.isNotEmpty && s.email.toLowerCase() == user.email.toLowerCase()) ||
        (s.name.isNotEmpty && s.name.toLowerCase() == user.name.toLowerCase())).firstOrNull;

    if (match != null) return match;

    final empId = user.employeeId?.isNotEmpty == true
        ? user.employeeId!
        : (user.id.length >= 4 ? 'EMP${user.id.substring(0, 4).toUpperCase()}' : user.id);

    final dept = user.role.toLowerCase().contains('cash')
        ? 'Front Office'
        : (user.role.toLowerCase().contains('chef') || user.role.toLowerCase().contains('kitchen')
            ? 'Kitchen Section'
            : (user.role.toLowerCase().contains('waiter') || user.role.toLowerCase().contains('cap')
                ? 'Dining & Service'
                : (user.isOwner || user.isAdmin ? 'Management' : 'Operations')));

    final fallbackPhone = (user.phone?.isNotEmpty == true)
        ? user.phone!
        : (db.restaurant?.phone.isNotEmpty == true ? db.restaurant!.phone : '');

    final isOwnerUser = user.isOwner || user.role.toLowerCase() == 'owner' || user.isAdmin;
    final resolvedAvatar = user.profilePhotoPath?.isNotEmpty == true
        ? user.profilePhotoPath!
        : (isOwnerUser ? (db.companyLogoPath ?? db.restaurant?.logoUrl ?? '') : '');

    return StaffModel(
      id: user.id,
      name: user.name,
      employeeId: empId,
      email: user.email,
      phone: fallbackPhone,
      role: user.role.isNotEmpty ? user.role : (isOwnerUser ? 'Owner' : 'Staff'),
      status: 'Active',
      department: dept,
      salary: 0,
      notes: '',
      pin: user.pin,
      avatarUrl: resolvedAvatar,
      language: 'English',
      theme: 'System',
      defaultScreen: 'POS',
      enableBiometric: false,
      forcePasswordChange: false,
      sendWelcomeEmail: false,
      joiningDate: DateTime.now(),
      createdAt: DateTime.now(),
      permissions: user.permissions,
      shift: 'Morning (09:00 AM - 06:00 PM)',
    );
  }

  String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text;
    return text.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- Neumorphic Style Builders ---

  Widget _buildNeumorphicCard({
    required Widget child,
    Color? color,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    double elevation = 4.0,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF4F6FB),
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-elevation, -elevation),
            blurRadius: elevation * 2,
          ),
          BoxShadow(
            color: const Color(0x140F172A),
            offset: Offset(elevation, elevation),
            blurRadius: elevation * 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildNeumorphicInset({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    Color? color,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFEFF3F9),
        borderRadius: borderRadius ?? BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0F172A),
            offset: Offset(1.5, 1.5),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-1.5, -1.5),
            blurRadius: 3,
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final staff = _getEffectiveStaff(db);
    final restaurant = db.restaurant;
    final restaurantName = (restaurant?.name.isNotEmpty == true)
        ? restaurant!.name
        : (db.currentUser?.companyName?.isNotEmpty == true ? db.currentUser!.companyName! : 'Apna POS Store');
    final restaurantTagline = (restaurant?.tagline.isNotEmpty == true) ? restaurant!.tagline : 'Authentic Flavors & Swift Service';
    final companyLogoPath = db.companyLogoPath;

    final department = staff.department.isNotEmpty ? staff.department : 'Dining & Service';
    final empId = staff.employeeId.isNotEmpty ? staff.employeeId : staff.id;
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

    return Container(
      color: const Color(0xFFEFF3F9), // Soft Neumorphic Backdrop
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Physical ID Card in Neumorphic Vessel
                      SizedBox(
                        width: 340,
                        child: _buildIdCardWrapper(
                          staff: staff,
                          restaurantName: restaurantName,
                          tagline: restaurantTagline,
                          companyLogoPath: companyLogoPath,
                          department: department,
                          empId: empId,
                          phone: phone,
                          email: email,
                          joinDateStr: joinDateStr,
                          qrPayload: qrPayload,
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Right: Wrapped Neumorphic Information Cards
                      Expanded(
                        child: _buildWrappedDetailsSection(
                          staff: staff,
                          department: department,
                          empId: empId,
                          phone: phone,
                          email: email,
                          joinDateStr: joinDateStr,
                          restaurantName: restaurantName,
                          restaurantAddress: restaurant?.address ?? 'Main Branch Store',
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Mobile: Physical ID Card on Top
                      _buildIdCardWrapper(
                        staff: staff,
                        restaurantName: restaurantName,
                        tagline: restaurantTagline,
                        companyLogoPath: companyLogoPath,
                        department: department,
                        empId: empId,
                        phone: phone,
                        email: email,
                        joinDateStr: joinDateStr,
                        qrPayload: qrPayload,
                      ),
                      const SizedBox(height: 18),

                      // Mobile: Wrapped Details Cards Below
                      _buildWrappedDetailsSection(
                        staff: staff,
                        department: department,
                        empId: empId,
                        phone: phone,
                        email: email,
                        joinDateStr: joinDateStr,
                        restaurantName: restaurantName,
                        restaurantAddress: restaurant?.address ?? 'Main Branch Store',
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- Active Status Badge Helper ---
  Widget _buildActiveStatusBadge(String status, {bool compact = false}) {
    final isActive = status.toLowerCase() != 'inactive' && status.toLowerCase() != 'disabled';
    final color = isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bgColor = isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final borderColor = isActive ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final text = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 3,
                  spreadRadius: 0.8,
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // --- ID Card Wrapper (Neumorphic Card enclosing the Badge) ---
  Widget _buildIdCardWrapper({
    required StaffModel staff,
    required String restaurantName,
    required String tagline,
    required String? companyLogoPath,
    required String department,
    required String empId,
    required String phone,
    required String email,
    required String joinDateStr,
    required String qrPayload,
  }) {
    return _buildNeumorphicCard(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(22),
      elevation: 5.0,
      child: InkWell(
        onTap: () => StaffIdCardDialog.show(context, staff),
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0x1A2563EB),
        highlightColor: const Color(0x0D2563EB),
        child: _buildIdCardSection(
          staff: staff,
          restaurantName: restaurantName,
          tagline: tagline,
          companyLogoPath: companyLogoPath,
          department: department,
          empId: empId,
          phone: phone,
          email: email,
          joinDateStr: joinDateStr,
          qrPayload: qrPayload,
        ),
      ),
    );
  }

  // --- Physical ID Card Component ---
  Widget _buildIdCardSection({
    required StaffModel staff,
    required String restaurantName,
    required String tagline,
    required String? companyLogoPath,
    required String department,
    required String empId,
    required String phone,
    required String email,
    required String joinDateStr,
    required String qrPayload,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lanyard Ribbon Strap & Metallic Clip Graphic
        _buildLanyardClip(),

        // Physical ID Card Body (Sized to match the full outer box)
        Container(
          width: double.infinity,
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
                // Decorative Top Wave Curves
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ProfileIdCardWavePainter(),
                  ),
                ),

                // Background Logo Watermark (0.075 opacity)
                _buildWatermarkLogo(companyLogoPath),

                // Card Content Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Punch Slot
                    const SizedBox(height: 5),
                    Container(
                      width: 28,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Brand Header: Left Logo & Right Company Name
                    _buildBrandHeader(restaurantName, companyLogoPath),
                    const SizedBox(height: 8),

                    // Staff Photo Avatar
                    _buildStaffAvatar(staff, size: 72),
                    const SizedBox(height: 6),

                    // Staff Name (Bold & Title Case)
                    Text(
                      _toTitleCase(staff.name),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Role Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
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

                    // Centered 2-Column Details Box (Like Real ID Cards)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
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

                    // Bottom Dark Navy Wavy Footer with QR Code
                    _buildBottomWaveFooter(
                      restaurantName: restaurantName,
                      tagline: tagline,
                      qrData: qrPayload,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Wrapped Details Section (Neumorphic Cards) ---
  Widget _buildWrappedDetailsSection({
    required StaffModel staff,
    required String department,
    required String empId,
    required String phone,
    required String email,
    required String joinDateStr,
    required String restaurantName,
    required String restaurantAddress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Personal & Job Information (Wrapped Grid / Tiles)
        _buildSectionCard(
          title: 'Personal & Job Information',
          icon: Icons.person_rounded,
          iconColor: const Color(0xFF2563EB),
          iconBgColor: const Color(0xFFEFF6FF),
          trailing: _buildActiveStatusBadge(staff.status),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 420;

              if (isTwoCol) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Full Name',
                            value: _toTitleCase(staff.name),
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Employee ID',
                            value: empId,
                            icon: Icons.pin_outlined,
                            onCopy: () => _copyToClipboard(empId, 'Employee ID'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Department',
                            value: department,
                            icon: Icons.apartment_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Designation / Role',
                            value: _toTitleCase(staff.role),
                            icon: Icons.work_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Contact Number',
                            value: phone,
                            icon: Icons.phone_outlined,
                            onCopy: () => _copyToClipboard(phone, 'Phone Number'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Email Address',
                            value: email,
                            icon: Icons.mail_outline_rounded,
                            onCopy: () => _copyToClipboard(email, 'Email Address'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Date of Joining',
                            value: joinDateStr,
                            icon: Icons.calendar_today_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Working Shift',
                            value: staff.shift.isNotEmpty ? staff.shift : 'General Shift (09:00 AM - 06:00 PM)',
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildNeumorphicInfoTile(
                      label: 'Full Name',
                      value: _toTitleCase(staff.name),
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Employee ID',
                      value: empId,
                      icon: Icons.pin_outlined,
                      onCopy: () => _copyToClipboard(empId, 'Employee ID'),
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Department',
                      value: department,
                      icon: Icons.apartment_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Designation / Role',
                      value: _toTitleCase(staff.role),
                      icon: Icons.work_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Contact Number',
                      value: phone,
                      icon: Icons.phone_outlined,
                      onCopy: () => _copyToClipboard(phone, 'Phone Number'),
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Email Address',
                      value: email,
                      icon: Icons.mail_outline_rounded,
                      onCopy: () => _copyToClipboard(email, 'Email Address'),
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Date of Joining',
                      value: joinDateStr,
                      icon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Working Shift',
                      value: staff.shift.isNotEmpty ? staff.shift : 'General Shift (09:00 AM - 06:00 PM)',
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                );
              }
            },
          ),
        ),
        const SizedBox(height: 16),

        // Card 2: Role & Access Permissions (Wrapped Neumorphic Chips)
        _buildSectionCard(
          title: 'Assigned Role Permissions',
          icon: Icons.verified_user_rounded,
          iconColor: const Color(0xFF16A34A),
          iconBgColor: const Color(0xFFDCFCE7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modules and capabilities authorized for this staff profile:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildPermissionChips(staff),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 3: Store & Security Details (Neumorphic Inset Tiles)
        _buildSectionCard(
          title: 'Store & Security Details',
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFF7C3AED),
          iconBgColor: const Color(0xFFF3E8FF),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 420;

              if (isTwoCol) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Store Name',
                            value: restaurantName,
                            icon: Icons.store_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Store Address',
                            value: restaurantAddress,
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Quick Login PIN',
                            value: staff.pin.isNotEmpty ? '•••• (PIN Configured)' : '1234 (Default PIN)',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildNeumorphicInfoTile(
                            label: 'Biometric Access',
                            value: staff.enableBiometric ? 'Enabled (Fingerprint / Face ID)' : 'Disabled',
                            icon: Icons.fingerprint_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildNeumorphicInfoTile(
                      label: 'Store Name',
                      value: restaurantName,
                      icon: Icons.store_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Store Address',
                      value: restaurantAddress,
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Quick Login PIN',
                      value: staff.pin.isNotEmpty ? '•••• (PIN Configured)' : '1234 (Default PIN)',
                      icon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildNeumorphicInfoTile(
                      label: 'Biometric Access',
                      value: staff.enableBiometric ? 'Enabled (Fingerprint / Face ID)' : 'Disabled',
                      icon: Icons.fingerprint_rounded,
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }

  // --- Reusable Neumorphic Section Card ---
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    Widget? trailing,
    required Widget child,
  }) {
    return _buildNeumorphicCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      elevation: 4.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Soft Embossed Icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                    boxShadow: const [
                      BoxShadow(color: Colors.white, offset: Offset(-1, -1), blurRadius: 2),
                      BoxShadow(color: Color(0x10000000), offset: Offset(1, 1), blurRadius: 2),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  // --- Neumorphic Inset Info Tile (Recessed Tile for Data Fields) ---
  Widget _buildNeumorphicInfoTile({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
  }) {
    return _buildNeumorphicInset(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onCopy != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Permission Chips (Wrapped Neumorphic Chips) ---
  List<Widget> _buildPermissionChips(StaffModel staff) {
    final permissions = staff.permissions;
    final bool hasAll = permissions.contains('*') || permissions.contains('all');

    final availableModules = [
      {'id': 'pos', 'label': 'POS & Quick Billing', 'icon': Icons.point_of_sale_rounded},
      {'id': 'tables', 'label': 'Table Management', 'icon': Icons.table_restaurant_rounded},
      {'id': 'orders', 'label': 'My Orders & KDS', 'icon': Icons.receipt_long_rounded},
      {'id': 'menu', 'label': 'Menu & Categories', 'icon': Icons.dinner_dining_rounded},
      {'id': 'reports', 'label': 'Sales Reports', 'icon': Icons.bar_chart_rounded},
      {'id': 'crm', 'label': 'Customer CRM', 'icon': Icons.people_alt_rounded},
      {'id': 'inventory', 'label': 'Inventory Access', 'icon': Icons.inventory_2_rounded},
    ];

    return availableModules.map((mod) {
      final isPermitted = hasAll || permissions.contains(mod['id']) || staff.role.toLowerCase() == 'manager';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
        decoration: BoxDecoration(
          color: isPermitted ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPermitted ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPermitted ? const Color(0x102563EB) : Colors.transparent,
              offset: const Offset(0, 1.5),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermitted ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              size: 13.5,
              color: isPermitted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              mod['label'] as String,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isPermitted ? FontWeight.w800 : FontWeight.w600,
                color: isPermitted ? const Color(0xFF1E40AF) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // --- ID Card Graphic Helpers ---

  Widget _buildLanyardClip() {
    return Column(
      children: [
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

  Widget _buildBrandHeader(String restaurantName, String? logoPath) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.8),
              boxShadow: const [
                BoxShadow(color: Color(0x1E000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: ClipOval(
              child: _buildCompanyLogoImage(logoPath, 55, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restaurantName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF991B1B),
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
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                    letterSpacing: 2.0,
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

  Widget _buildStaffAvatar(StaffModel staff, {double size = 72}) {
    final db = DatabaseService();
    final bool isOwnerStaff = staff.role.toLowerCase() == 'owner' ||
        staff.role.toLowerCase() == 'admin' ||
        (db.currentUser != null && (db.currentUser!.isOwner || db.currentUser!.isAdmin) &&
            (db.currentUser!.id == staff.id || db.currentUser!.employeeId == staff.employeeId || staff.name.toLowerCase() == db.currentUser!.name.toLowerCase()));

    String effectivePhoto = staff.avatarUrl.trim();
    if (effectivePhoto.isEmpty) {
      if (db.currentUser != null && (db.currentUser!.id == staff.id || db.currentUser!.employeeId == staff.employeeId)) {
        effectivePhoto = db.currentUser!.profilePhotoPath?.trim() ?? '';
      }
      if (effectivePhoto.isEmpty && isOwnerStaff) {
        effectivePhoto = db.companyLogoPath ?? db.restaurant?.logoUrl ?? '';
      }
    }

    Widget avatarContent;
    if (effectivePhoto.isNotEmpty) {
      if (effectivePhoto.startsWith('data:image') || effectivePhoto.startsWith('data:') || (effectivePhoto.length > 80 && !effectivePhoto.contains('/') && !effectivePhoto.contains('\\'))) {
        try {
          final commaIdx = effectivePhoto.indexOf(',');
          final cleanBase64 = commaIdx != -1 ? effectivePhoto.substring(commaIdx + 1) : effectivePhoto;
          final bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
          avatarContent = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                isOwnerStaff ? _buildDefaultCompanyLogo(size, fit: BoxFit.cover) : _buildInitialsAvatar(staff, size),
          );
        } catch (_) {
          avatarContent = isOwnerStaff ? _buildDefaultCompanyLogo(size, fit: BoxFit.cover) : _buildInitialsAvatar(staff, size);
        }
      } else if (effectivePhoto.startsWith('http://') || effectivePhoto.startsWith('https://')) {
        avatarContent = Image.network(
          effectivePhoto,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              isOwnerStaff ? _buildDefaultCompanyLogo(size, fit: BoxFit.cover) : _buildInitialsAvatar(staff, size),
        );
      } else if (effectivePhoto.startsWith('assets/')) {
        avatarContent = Image.asset(
          effectivePhoto,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              isOwnerStaff ? _buildDefaultCompanyLogo(size, fit: BoxFit.cover) : _buildInitialsAvatar(staff, size),
        );
      } else if (!effectivePhoto.contains('_selected') && File(effectivePhoto).existsSync()) {
        avatarContent = Image.file(
          File(effectivePhoto),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              isOwnerStaff ? _buildDefaultCompanyLogo(size, fit: BoxFit.cover) : _buildInitialsAvatar(staff, size),
        );
      } else {
        avatarContent = isOwnerStaff ? _buildCompanyLogoImage(db.companyLogoPath, size, fit: BoxFit.cover) : _buildInitialsAvatar(staff, size);
      }
    } else {
      avatarContent = isOwnerStaff ? _buildCompanyLogoImage(db.companyLogoPath, size, fit: BoxFit.cover) : _buildInitialsAvatar(staff, size);
    }

    final isActive = staff.status.toLowerCase() != 'inactive' && staff.status.toLowerCase() != 'disabled';
    final statusColor = isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    final avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarCircle,
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(StaffModel staff, double size) {
    final db = DatabaseService();
    final bool isOwnerStaff = staff.role.toLowerCase() == 'owner' ||
        staff.role.toLowerCase() == 'admin' ||
        (db.currentUser != null && (db.currentUser!.isOwner || db.currentUser!.isAdmin) &&
            (db.currentUser!.id == staff.id || db.currentUser!.employeeId == staff.employeeId || staff.name.toLowerCase() == db.currentUser!.name.toLowerCase()));

    if (isOwnerStaff) {
      return Container(
        width: size,
        height: size,
        color: Colors.white,
        alignment: Alignment.center,
        child: _buildCompanyLogoImage(db.companyLogoPath, size, fit: BoxFit.cover),
      );
    }

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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 12.5, color: const Color(0xFF2563EB)),
          const SizedBox(width: 5),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.1,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
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

  Widget _buildWatermarkLogo(String? photoPath) {
    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: 0.075,
          child: SizedBox(
            width: 180,
            height: 180,
            child: _buildCompanyLogoImage(photoPath, 180, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyLogoImage(String? photoPath, double size, {BoxFit fit = BoxFit.contain}) {
    if (photoPath != null && photoPath.isNotEmpty) {
      if (photoPath.startsWith('data:image') || photoPath.startsWith('data:') || (photoPath.length > 80 && !photoPath.contains('/') && !photoPath.contains('\\'))) {
        try {
          final commaIdx = photoPath.indexOf(',');
          final cleanBase64 = commaIdx != -1 ? photoPath.substring(commaIdx + 1) : photoPath;
          final bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit),
          );
        } catch (_) {}
      } else if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        return Image.network(
          photoPath,
          width: size,
          height: size,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit),
        );
      } else if (photoPath.startsWith('assets/')) {
        return Image.asset(
          photoPath,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit),
        );
      } else if (!photoPath.contains('_selected') && File(photoPath).existsSync()) {
        return Image.file(
          File(photoPath),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCompanyLogo(size, fit: fit),
        );
      }
    }

    return _buildDefaultCompanyLogo(size, fit: fit);
  }

  Widget _buildDefaultCompanyLogo(double size, {BoxFit fit = BoxFit.contain}) {
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
        errorBuilder: (context, error, stackTrace) => _buildCompanyFallbackInitial(size),
      ),
    );
  }

  Widget _buildCompanyFallbackInitial(double size) {
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
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomWaveFooter({
    required String restaurantName,
    required String tagline,
    required String qrData,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ProfileFooterWavePainter(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
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
                  size: 38.0,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 34,
                color: const Color(0x33FFFFFF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      restaurantName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'R E S T A U R A N T',
                      style: TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: const TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60A5FA),
                        letterSpacing: 1.0,
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

class _ProfileFooterWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
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

class _ProfileIdCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, 0);
    path1.lineTo(size.width * 0.45, 0);
    path1.cubicTo(size.width * 0.35, size.height * 0.12, 0, size.height * 0.18, 0, size.height * 0.24);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(size.width, 0);
    path2.lineTo(size.width * 0.55, 0);
    path2.cubicTo(size.width * 0.65, size.height * 0.10, size.width, size.height * 0.16, size.width, size.height * 0.22);
    path2.close();
    canvas.drawPath(path2, paint2);

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
