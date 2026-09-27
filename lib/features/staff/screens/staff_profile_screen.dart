import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../widgets/staff_id_card_dialog.dart';

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
        id: 'staff_001',
        name: 'Staff Member',
        employeeId: 'EMP001',
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
        : (user.id.length >= 4 ? 'EMP${user.id.substring(0, 4).toUpperCase()}' : 'EMP001');

    final dept = user.role.toLowerCase().contains('cash')
        ? 'Front Office'
        : (user.role.toLowerCase().contains('chef') || user.role.toLowerCase().contains('kitchen')
            ? 'Kitchen Section'
            : (user.role.toLowerCase().contains('waiter') || user.role.toLowerCase().contains('cap')
                ? 'Dining & Service'
                : (user.isOwner || user.isAdmin ? 'Management' : 'Operations')));

    return StaffModel(
      id: user.id.isNotEmpty ? user.id : 'staff_001',
      name: user.name.isNotEmpty ? user.name : 'Staff Member',
      employeeId: empId,
      email: user.email,
      phone: user.phone ?? '+91 9709593706',
      role: user.role.isNotEmpty ? user.role : 'Staff',
      status: 'Active',
      department: dept,
      salary: 0,
      notes: '',
      pin: user.pin,
      avatarUrl: user.profilePhotoPath ?? '',
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
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF1E3A8A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final staff = _getEffectiveStaff(db);
    final restaurant = db.restaurant;
    final restaurantName = (restaurant?.name.isNotEmpty == true) ? restaurant!.name : 'MOTI MAHAL';
    final restaurantTagline = (restaurant?.tagline.isNotEmpty == true) ? restaurant!.tagline : 'Authentic Flavors & Swift Service';
    final companyLogoPath = db.companyLogoPath;

    final department = staff.department.isNotEmpty ? staff.department : 'Dining & Service';
    final empId = staff.employeeId.isNotEmpty ? staff.employeeId : 'EMP001';
    final phone = staff.phone.isNotEmpty ? staff.phone : '+91 9709593706';
    final email = staff.email.isNotEmpty
        ? staff.email
        : '${staff.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@${restaurantName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}.com';

    final joinDateStr = staff.joiningDate != null
        ? DateFormat('dd MMM yyyy').format(staff.joiningDate!)
        : DateFormat('dd MMM yyyy').format(staff.createdAt);

    final qrPayload = 'STAFF-ID:$empId|NAME:${staff.name}|ROLE:${staff.role}|DEPT:$department|ORG:$restaurantName';

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 740;

                if (isWide) {
                  // Desktop / Tablet Two-Column Layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Physical ID Card (Tap to view full card)
                      SizedBox(
                        width: 320,
                        child: Center(
                          child: InkWell(
                            onTap: () => StaffIdCardDialog.show(context, staff),
                            borderRadius: BorderRadius.circular(16),
                            child: _buildIdCardSection(
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
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right: Detailed Wrapped Information Cards
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
                  // Mobile Single-Column Layout: ID Card on Top, Details Below
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Section: Physical ID Card (Tap to view full card)
                      InkWell(
                        onTap: () => StaffIdCardDialog.show(context, staff),
                        borderRadius: BorderRadius.circular(16),
                        child: _buildIdCardSection(
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
                      const SizedBox(height: 20),

                      // Details Section (Wrapped Cards)
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

  // Top Section: Physical ID Card Widget
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

        // Physical ID Card Body
        Container(
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
                      width: 30,
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
                    _buildStaffAvatar(staff),
                    const SizedBox(height: 6),

                    // Staff Name (Bold & Title Case)
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

                    // Role Badge Pill
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

                    // Centered 2-Column Details Box (Like Real ID Cards)
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

                    // Bottom Dark Navy Wavy Footer with QR Code
                    _buildBottomWaveFooter(
                      restaurantName: restaurantName,
                      tagline: tagline,
                      qrData: qrPayload,
                    ),
                  ],
                ),

                // Top Right Corner: Active / Inactive Status Badge (Only shown in Staff Profile Screen)
                Positioned(
                  top: 7,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: staff.isActive
                          ? const Color(0xFFDCFCE7).withValues(alpha: 0.95)
                          : const Color(0xFFFEE2E2).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: staff.isActive ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                        width: 0.9,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: staff.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          staff.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: staff.isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            letterSpacing: 0.2,
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
      ],
    );
  }

  // Wrapped Details Section (Cards for Personal Details, Permissions, and Store Details)
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
        // 1. Personal & Employment Information Card
        _buildSectionCard(
          title: 'Personal & Job Information',
          icon: Icons.person_rounded,
          iconColor: const Color(0xFF2563EB),
          iconBgColor: const Color(0xFFEFF6FF),
          child: Column(
            children: [
              _buildDetailItem(
                label: 'Full Name',
                value: _toTitleCase(staff.name),
                icon: Icons.badge_outlined,
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Employee ID',
                value: empId,
                icon: Icons.pin_outlined,
                onCopy: () => _copyToClipboard(empId, 'Employee ID'),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Department',
                value: department,
                icon: Icons.apartment_rounded,
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Designation / Role',
                value: _toTitleCase(staff.role),
                icon: Icons.work_outline_rounded,
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Contact Number',
                value: phone,
                icon: Icons.phone_outlined,
                onCopy: () => _copyToClipboard(phone, 'Phone Number'),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Email Address',
                value: email,
                icon: Icons.mail_outline_rounded,
                onCopy: () => _copyToClipboard(email, 'Email Address'),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Date of Joining',
                value: joinDateStr,
                icon: Icons.calendar_today_outlined,
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Working Shift',
                value: staff.shift.isNotEmpty ? staff.shift : 'General Shift (09:00 AM - 06:00 PM)',
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Role & Access Permissions Card
        _buildSectionCard(
          title: 'Assigned Role Permissions',
          icon: Icons.verified_user_rounded,
          iconColor: const Color(0xFF16A34A),
          iconBgColor: const Color(0xFFDCFCE7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modules and capabilities currently authorized for this staff profile:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
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

        // 3. Organization & Security Overview Card
        _buildSectionCard(
          title: 'Store & Security Details',
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFF7C3AED),
          iconBgColor: const Color(0xFFF3E8FF),
          child: Column(
            children: [
              _buildDetailItem(
                label: 'Store Name',
                value: restaurantName,
                icon: Icons.store_rounded,
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Store Address',
                value: restaurantAddress,
                icon: Icons.location_on_outlined,
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Quick Login PIN',
                value: staff.pin.isNotEmpty ? '•••• (PIN Configured)' : '1234 (Default PIN)',
                icon: Icons.lock_outline_rounded,
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 16),
              _buildDetailItem(
                label: 'Biometric Access',
                value: staff.enableBiometric ? 'Enabled (Fingerprint / Face ID)' : 'Disabled',
                icon: Icons.fingerprint_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Section Card Wrapper
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // Detail Item Row
  Widget _buildDetailItem({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (onCopy != null)
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.copy_rounded, size: 15, color: Color(0xFF2563EB)),
            ),
          ),
      ],
    );
  }

  // Permission Badges List
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPermitted ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPermitted ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermitted ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              size: 14,
              color: isPermitted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              mod['label'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isPermitted ? FontWeight.w800 : FontWeight.w600,
                color: isPermitted ? const Color(0xFF1E40AF) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ID Card Graphic Helper Components
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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

  Widget _buildStaffAvatar(StaffModel staff) {
    const double size = 72;
    Widget avatarContent;

    if (staff.avatarUrl.isNotEmpty) {
      if (staff.avatarUrl.startsWith('http://') || staff.avatarUrl.startsWith('https://')) {
        avatarContent = Image.network(
          staff.avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(staff, size),
        );
      } else if (File(staff.avatarUrl).existsSync()) {
        avatarContent = Image.file(
          File(staff.avatarUrl),
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

  Widget _buildCompanyLogoImage(String? photoPath, double size, {BoxFit fit = BoxFit.contain}) {
    if (photoPath != null && photoPath.isNotEmpty) {
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        return Image.network(
          photoPath,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildCompanyFallbackInitial(size),
        );
      } else if (!photoPath.contains('_selected') && File(photoPath).existsSync()) {
        return Image.file(
          File(photoPath),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildCompanyFallbackInitial(size),
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
            errorBuilder: (context, error, stackTrace) => _buildCompanyFallbackInitial(size),
          );
        } catch (_) {}
      } else if (photoPath.startsWith('assets/')) {
        return Image.asset(
          photoPath,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildCompanyFallbackInitial(size),
        );
      }
    }

    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildCompanyFallbackInitial(size),
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
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
              Container(
                width: 1,
                height: 36,
                color: const Color(0x33FFFFFF),
              ),
              const SizedBox(width: 10),
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
