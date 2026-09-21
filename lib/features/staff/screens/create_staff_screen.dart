import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/services/staff_service.dart';

class CreateStaffScreen extends StatefulWidget {
  final VoidCallback? onStaffCreated;

  const CreateStaffScreen({
    super.key,
    this.onStaffCreated,
  });

  @override
  State<CreateStaffScreen> createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends State<CreateStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final StaffService _staffService = StaffService();
  final DatabaseService _db = DatabaseService();

  // Text Controllers
  final _nameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Basic & Work State
  String _selectedRole = 'Cashier';
  String _selectedCountryCode = '+91';
  String _selectedDepartment = 'Billing / Counter';
  String _selectedReportingTo = 'Store Owner / Admin';
  String _selectedLocation = 'Main Store';
  String _selectedShift = 'Morning Shift (8 AM - 4 PM)';

  // Security State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _forcePasswordChange = false;

  // Permissions State
  String _selectedPermissionCategory = 'pos_orders';
  final Set<String> _selectedPermissions = {
    'pos_access',
    'pos_apply_discount',
    'pos_view_all_orders',
    'pos_manage_tables',
    'pos_takeaway_delivery',
    'products_view',
    'inventory_view',
    'customers_view',
    'customers_add_edit',
    'reports_daily_sales',
  };

  // Preferences State
  String _selectedLanguage = 'English';
  String _selectedTheme = 'Light';
  String _selectedDefaultScreen = 'Dashboard';
  bool _enableBiometric = false;

  // Account Status & Options
  bool _isActive = true;
  bool _sendWelcomeEmail = true;
  bool _isSubmitting = false;

  File? _avatarImageFile;
  final ImagePicker _picker = ImagePicker();

  // Lists of Options
  final List<String> _roleOptions = [
    'Admin',
    'Manager',
    'Cashier',
    'Sales',
    'Inventory',
    'Support',
    'Chef',
    'Waiter',
    'Other',
  ];

  final List<String> _departmentOptions = [
    'Billing / Counter',
    'Kitchen',
    'Dining & Service',
    'Inventory / Stock',
    'Management',
    'Accounts',
    'Customer Support',
    'Other',
  ];

  final List<String> _reportingToOptions = [
    'Store Owner / Admin',
    'General Manager',
    'Store Supervisor',
    'Shift Lead',
    'None',
  ];

  final List<String> _locationOptions = [
    'Main Store',
    'Counter 1',
    'Kitchen',
    'Outlet 1',
    'Takeaway Counter',
    'Floor 1',
    'Floor 2',
    'Other',
  ];

  final List<String> _shiftOptions = [
    'Morning Shift (8 AM - 4 PM)',
    'Evening Shift (4 PM - 12 AM)',
    'Night Shift (12 AM - 8 AM)',
    'Full Day / General (9 AM - 9 PM)',
    'Flexible Shift',
  ];

  final List<String> _languageOptions = [
    'English',
    'Hindi',
    'Gujarati',
    'Marathi',
    'Bengali',
    'Spanish',
    'Arabic',
  ];

  final List<String> _themeOptions = [
    'Light',
    'Dark',
    'System Default',
  ];

  final List<String> _defaultScreenOptions = [
    'Dashboard',
    'POS Billing',
    'Tables / Floor',
    'Orders List',
    'KDS Kitchen',
  ];

  final List<String> _countryCodes = [
    '+91',
    '+1',
    '+44',
    '+971',
    '+966',
    '+61',
    '+65',
    '+880',
    '+977',
  ];

  // Category definitions for permissions
  final List<Map<String, dynamic>> _permissionCategories = [
    {'id': 'pos_orders', 'label': 'POS & Orders', 'icon': Icons.shopping_cart_outlined},
    {'id': 'products', 'label': 'Products', 'icon': Icons.inventory_2_outlined},
    {'id': 'inventory', 'label': 'Inventory', 'icon': Icons.archive_outlined},
    {'id': 'customers', 'label': 'Customers', 'icon': Icons.people_outline_rounded},
    {'id': 'reports', 'label': 'Reports', 'icon': Icons.insert_chart_outlined_rounded},
    {'id': 'settings', 'label': 'Settings', 'icon': Icons.settings_outlined},
    {'id': 'others', 'label': 'Others', 'icon': Icons.more_horiz_rounded},
  ];

  // Map of permissions by category
  final Map<String, List<Map<String, String>>> _permissionsByCategory = {
    'pos_orders': [
      {'id': 'pos_access', 'title': 'Access POS', 'subtitle': 'Allow billing and order management'},
      {'id': 'pos_apply_discount', 'title': 'Apply Discount', 'subtitle': 'Allow to apply bill discounts'},
      {'id': 'pos_cancel_orders', 'title': 'Cancel Orders', 'subtitle': 'Allow to cancel orders'},
      {'id': 'pos_view_all_orders', 'title': 'View All Orders', 'subtitle': 'View orders from all staff'},
      {'id': 'pos_manage_tables', 'title': 'Manage Tables', 'subtitle': 'Create, edit and manage tables'},
      {'id': 'pos_kds', 'title': 'Kitchen Display (KDS)', 'subtitle': 'Access kitchen display system'},
      {'id': 'pos_takeaway_delivery', 'title': 'Take Away & Delivery Orders', 'subtitle': 'Handle online and takeaway orders'},
    ],
    'products': [
      {'id': 'products_view', 'title': 'View Products', 'subtitle': 'View items, prices and modifiers'},
      {'id': 'products_add_edit', 'title': 'Add / Edit Products', 'subtitle': 'Create and update menu catalog'},
      {'id': 'products_delete', 'title': 'Delete Products', 'subtitle': 'Remove menu items from store'},
      {'id': 'products_categories', 'title': 'Manage Categories', 'subtitle': 'Organize product categories'},
    ],
    'inventory': [
      {'id': 'inventory_view', 'title': 'View Stock', 'subtitle': 'Monitor current inventory levels'},
      {'id': 'inventory_adjust', 'title': 'Stock In / Stock Out', 'subtitle': 'Log inventory adjustments and wastage'},
      {'id': 'inventory_alerts', 'title': 'Low Stock Alerts', 'subtitle': 'Receive low inventory notifications'},
      {'id': 'inventory_purchases', 'title': 'Purchase Orders', 'subtitle': 'Manage supplier bills and POs'},
    ],
    'customers': [
      {'id': 'customers_view', 'title': 'View Customer List', 'subtitle': 'Access directory of customer accounts'},
      {'id': 'customers_add_edit', 'title': 'Add / Edit Customers', 'subtitle': 'Register customer profiles & loyalty'},
      {'id': 'customers_crm', 'title': 'CRM Campaigns', 'subtitle': 'Send promotions via SMS/WhatsApp'},
      {'id': 'customers_khata', 'title': 'Customer Credit / Khata', 'subtitle': 'Manage customer credit ledger'},
    ],
    'reports': [
      {'id': 'reports_daily_sales', 'title': 'Daily Sales Report', 'subtitle': 'View day-end sales summary'},
      {'id': 'reports_financial', 'title': 'Financial Reports', 'subtitle': 'Access profit/loss and tax breakdowns'},
      {'id': 'reports_export', 'title': 'Export Data', 'subtitle': 'Download reports in Excel and PDF'},
      {'id': 'reports_staff_performance', 'title': 'Staff Performance', 'subtitle': 'Track individual cashier sales'},
    ],
    'settings': [
      {'id': 'settings_store_profile', 'title': 'Business Profile', 'subtitle': 'Modify store information and branding'},
      {'id': 'settings_printers', 'title': 'Printers & Hardware', 'subtitle': 'Configure thermal printers and KOT'},
      {'id': 'settings_taxes', 'title': 'Tax & Charges', 'subtitle': 'Set GST and service charge rates'},
      {'id': 'settings_payments', 'title': 'Payment Gateways', 'subtitle': 'Configure UPI / QR and POS terminal'},
    ],
    'others': [
      {'id': 'others_activity_logs', 'title': 'Activity Logs', 'subtitle': 'View security and action audit trail'},
      {'id': 'others_chotu_ai', 'title': 'Chotu AI Assistant', 'subtitle': 'Use Chotu voice and smart assistant'},
      {'id': 'others_offline_mode', 'title': 'Offline Mode', 'subtitle': 'Sync offline orders with cloud'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _autoGenerateEmployeeId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _autoGenerateEmployeeId() {
    final nextNumber = _db.staffList.length + 1;
    _employeeIdController.text = 'EMP${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> _pickAvatarImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _avatarImageFile = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('[CreateStaffScreen] Image pick error: $e');
    }
  }

  Future<void> _handleCreateStaff() async {
    if (_formKey.currentState?.validate() != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match. Please re-enter.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final phone = _phoneController.text.trim();
      final fullPhone = phone.isNotEmpty ? '$_selectedCountryCode $phone' : '';

      final newStaff = StaffModel(
        id: 'st_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        employeeId: _employeeIdController.text.trim().isNotEmpty
            ? _employeeIdController.text.trim()
            : 'EMP${(_db.staffList.length + 1).toString().padLeft(3, '0')}',
        email: _emailController.text.trim().toLowerCase(),
        phone: fullPhone,
        role: _selectedRole,
        department: _selectedDepartment,
        workLocation: _selectedLocation,
        reportingTo: _selectedReportingTo,
        shift: _selectedShift,
        language: _selectedLanguage,
        theme: _selectedTheme,
        defaultScreen: _selectedDefaultScreen,
        enableBiometric: _enableBiometric,
        sendWelcomeEmail: _sendWelcomeEmail,
        status: _isActive ? 'Active' : 'Inactive',
        password: password,
        forcePasswordChange: _forcePasswordChange,
        permissions: _selectedPermissions.toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await _staffService.createStaff(newStaff);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Staff member "${created?.name ?? newStaff.name}" created successfully! They can now log in with their credentials.',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        widget.onStaffCreated?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[CreateStaffScreen] Error creating staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to create staff: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Header Bar
                    _buildTopHeader(),
                    const SizedBox(height: 20),

                    // Windows 2-Column Responsive Layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isTwoColumn = constraints.maxWidth >= 960;
                        if (isTwoColumn) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column (50%)
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildBasicInfoCard(),
                                    const SizedBox(height: 16),
                                    _buildWorkDetailsCard(),
                                    const SizedBox(height: 16),
                                    _buildLoginSecurityCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right Column (50%)
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildPermissionsCard(),
                                    const SizedBox(height: 16),
                                    _buildPreferencesCard(),
                                    const SizedBox(height: 16),
                                    _buildAccountStatusCard(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // Stacked layout for smaller window sizes
                        return Column(
                          children: [
                            _buildBasicInfoCard(),
                            const SizedBox(height: 16),
                            _buildWorkDetailsCard(),
                            const SizedBox(height: 16),
                            _buildLoginSecurityCard(),
                            const SizedBox(height: 16),
                            _buildPermissionsCard(),
                            const SizedBox(height: 16),
                            _buildPreferencesCard(),
                            const SizedBox(height: 16),
                            _buildAccountStatusCard(),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Bottom Action Bar
                    _buildBottomActionBar(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Top Header Bar ---
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title & Subtitle (No back button, no cross button)
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Staff',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add a new team member to your business',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),

        // "View Staff List" Header Button
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.people_alt_outlined, size: 18),
          label: const Text(
            'View Staff List',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ==================== LEFT COLUMN CARDS ====================

  // --- 1. Basic Information Card ---
  Widget _buildBasicInfoCard() {
    return _buildCardWrapper(
      icon: Icons.person_outline_rounded,
      title: 'Basic Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Uploader
              _buildAvatarSection(),
              const SizedBox(width: 20),

              // Full Name, Employee ID & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Full Name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration(
                        hint: 'Enter full name',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Employee ID & Role Row
                    Row(
                      children: [
                        // Employee ID
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Employee ID *'),
                              const SizedBox(height: 6),
                              Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  TextFormField(
                                    controller: _employeeIdController,
                                    decoration: _inputDecoration(
                                      hint: 'EMP00X',
                                      icon: Icons.badge_outlined,
                                    ).copyWith(
                                      contentPadding: const EdgeInsets.only(
                                        left: 12,
                                        right: 90,
                                        top: 11,
                                        bottom: 11,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: _autoGenerateEmployeeId,
                                      child: const Text(
                                        'Auto-generate',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Role
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Role *'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _selectedRole,
                                decoration: _inputDecoration(
                                  hint: 'Select role',
                                  icon: Icons.work_outline_rounded,
                                ),
                                items: _roleOptions
                                    .map((r) => DropdownMenuItem(
                                          value: r,
                                          child: Text(r, style: const TextStyle(fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedRole = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Email Address & Mobile Number Row
          Row(
            children: [
              // Email Address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Email Address *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        hint: 'name@company.com',
                        icon: Icons.mail_outline_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email is required for staff login';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Mobile Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Mobile Number'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Country Code Dropdown
                        Container(
                          width: 84,
                          margin: const EdgeInsets.only(right: 6),
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedCountryCode,
                            decoration: _inputDecoration(hint: '+91', icon: Icons.phone_outlined)
                                .copyWith(
                              prefixIcon: null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                            ),
                            items: _countryCodes
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCountryCode = val);
                            },
                          ),
                        ),

                        // Phone Number input
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(
                              hint: '98765 43210',
                              icon: Icons.phone_android_rounded,
                            ).copyWith(prefixIcon: null),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatarImage,
          child: Stack(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  image: _avatarImageFile != null
                      ? DecorationImage(
                          image: FileImage(_avatarImageFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _avatarImageFile == null
                    ? const Icon(Icons.person_rounded, size: 44, color: Color(0xFF94A3B8))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload Photo',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const Text(
          'JPG, PNG (Max 2MB)',
          style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  // --- 2. Work Details Card ---
  Widget _buildWorkDetailsCard() {
    return _buildCardWrapper(
      icon: Icons.business_center_outlined,
      title: 'Work Details',
      child: Column(
        children: [
          Row(
            children: [
              // Department
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Department'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedDepartment,
                      decoration: _inputDecoration(hint: 'Select department', icon: Icons.domain_rounded),
                      items: _departmentOptions
                          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDepartment = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Reporting To
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Reporting To'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedReportingTo,
                      decoration: _inputDecoration(hint: 'Select manager', icon: Icons.supervisor_account_outlined),
                      items: _reportingToOptions
                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedReportingTo = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Work Location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Work Location'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedLocation,
                      decoration: _inputDecoration(hint: 'Select location', icon: Icons.location_on_outlined),
                      items: _locationOptions
                          .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLocation = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Shift / Working Hours
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Shift / Working Hours'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedShift,
                      decoration: _inputDecoration(hint: 'Select shift', icon: Icons.schedule_outlined),
                      items: _shiftOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedShift = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Login & Security Card (Password only, No PIN) ---
  Widget _buildLoginSecurityCard() {
    return _buildCardWrapper(
      icon: Icons.lock_outline_rounded,
      title: 'Login & Security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Set Password
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Set Password *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 19,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Password is required';
                        if (val.trim().length < 6) return 'At least 6 characters required';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Confirm Password
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Confirm Password *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 19,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please confirm password';
                        if (val.trim() != _passwordController.text.trim()) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Force Password Change Checkbox
          InkWell(
            onTap: () => setState(() => _forcePasswordChange = !_forcePasswordChange),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _forcePasswordChange,
                    activeColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _forcePasswordChange = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Force password change on first login',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RIGHT COLUMN CARDS ====================

  // --- 4. Permissions Card ---
  Widget _buildPermissionsCard() {
    final activePermissions = _permissionsByCategory[_selectedPermissionCategory] ?? [];

    return _buildCardWrapper(
      icon: Icons.shield_outlined,
      title: 'Permissions',
      subtitle: 'Set what this staff member can access',
      child: Container(
        height: 275,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Left Categories Sidebar (Tabs)
            Container(
              width: 155,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _permissionCategories.length,
                itemBuilder: (context, index) {
                  final cat = _permissionCategories[index];
                  final isSelected = cat['id'] == _selectedPermissionCategory;
                  return InkWell(
                    onTap: () => setState(() => _selectedPermissionCategory = cat['id'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 16,
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat['label'] as String,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Right Checkboxes List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: activePermissions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final perm = activePermissions[index];
                  final permId = perm['id']!;
                  final isChecked = _selectedPermissions.contains(permId);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isChecked) {
                          _selectedPermissions.remove(permId);
                        } else {
                          _selectedPermissions.add(permId);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: isChecked,
                              activeColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPermissions.add(permId);
                                  } else {
                                    _selectedPermissions.remove(permId);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  perm['title']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isChecked ? FontWeight.w700 : FontWeight.w600,
                                    color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  perm['subtitle']!,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
      ),
    );
  }

  // --- 5. Preferences Card ---
  Widget _buildPreferencesCard() {
    return _buildCardWrapper(
      icon: Icons.tune_rounded,
      title: 'Preferences',
      child: Column(
        children: [
          Row(
            children: [
              // Language
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Language'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedLanguage,
                      decoration: _inputDecoration(hint: 'Language', icon: Icons.language_rounded),
                      items: _languageOptions
                          .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLanguage = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Theme
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Theme'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedTheme,
                      decoration: _inputDecoration(hint: 'Theme', icon: Icons.wb_sunny_outlined),
                      items: _themeOptions
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTheme = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Default Screen
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Default Screen'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedDefaultScreen,
                      decoration: _inputDecoration(hint: 'Default screen', icon: Icons.dashboard_outlined),
                      items: _defaultScreenOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDefaultScreen = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Enable Biometric Login Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Biometric Login',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Use fingerprint for faster login',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enableBiometric,
                  activeThumbColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _enableBiometric = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Account Status Card ---
  Widget _buildAccountStatusCard() {
    return _buildCardWrapper(
      icon: Icons.power_settings_new_rounded,
      title: 'Account Status',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Active Status Switch
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Switch(
                      value: _isActive,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _isActive ? 'Staff member can login and access the system' : 'Access disabled',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right: Last Login Info Box
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Login',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Not logged in yet',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 1),
                        const Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'From Windows - Store Device',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Action Bar ---
  Widget _buildBottomActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Send welcome email checkbox
        InkWell(
          onTap: () => setState(() => _sendWelcomeEmail = !_sendWelcomeEmail),
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _sendWelcomeEmail,
                  activeColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => setState(() => _sendWelcomeEmail = val ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Send welcome email with login details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),

        // Right: Cancel & Create Staff Buttons
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _handleCreateStaff,
              icon: _isSubmitting
                  ? const SizedBox.shrink()
                  : const Icon(Icons.person_add_rounded, size: 18),
              label: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Create Staff',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Card Styling Wrapper ---
  Widget _buildCardWrapper({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final isRequired = label.contains('*');
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: isRequired ? const Color(0xFF1E293B) : const Color(0xFF475569),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}
