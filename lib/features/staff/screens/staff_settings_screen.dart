import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/services/staff_service.dart';

class StaffSettingsScreen extends StatefulWidget {
  final StaffModel staff;
  final VoidCallback? onStaffUpdated;

  const StaffSettingsScreen({
    super.key,
    required this.staff,
    this.onStaffUpdated,
  });

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen>
    with SingleTickerProviderStateMixin {
  final StaffService _staffService = StaffService();
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  late StaffModel _currentStaff;

  // Text Controllers
  late TextEditingController _nameController;
  late TextEditingController _employeeIdController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _salaryController;
  late TextEditingController _notesController;
  late TextEditingController _pinController;

  // Form State
  late String _selectedRole;
  late String _selectedDepartment;
  late String _selectedLocation;
  late String _selectedReportingTo;
  late String _selectedShift;
  late String _selectedLanguage;
  late String _selectedTheme;
  late String _selectedDefaultScreen;
  late bool _enableBiometric;
  late bool _isActive;
  late bool _forcePasswordChange;
  late bool _sendWelcomeEmail;
  late Set<String> _selectedPermissions;
  DateTime? _joiningDate;

  bool _isSaving = false;
  File? _avatarImageFile;
  final ImagePicker _picker = ImagePicker();

  // Dropdown Options
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
    'Operations',
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
    'Amit Sharma',
    'Store Owner / Admin',
    'General Manager',
    'Store Supervisor',
    'Shift Lead',
    'None',
  ];

  final List<String> _locationOptions = [
    'Main Outlet',
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
    'System',
  ];

  final List<String> _defaultScreenOptions = [
    'Dashboard',
    'POS Billing',
    'Tables / Floor',
    'Orders List',
    'KDS Kitchen',
    'Reports',
  ];

  // Dynamic Granular Permission Categories
  final Map<String, Map<String, dynamic>> _permissionCategories = {
    'pos_orders': {
      'label': 'POS & Orders',
      'icon': Icons.shopping_cart_outlined,
      'items': [
        {'id': 'pos_access', 'title': 'Access POS', 'subtitle': 'Allow billing and order management'},
        {'id': 'pos_apply_discount', 'title': 'Apply Discount', 'subtitle': 'Allow to apply bill discounts'},
        {'id': 'pos_cancel_orders', 'title': 'Cancel Orders', 'subtitle': 'Allow to cancel orders and refund items'},
        {'id': 'pos_view_all_orders', 'title': 'View All Orders', 'subtitle': 'View orders from all cashiers & staff'},
        {'id': 'pos_manage_tables', 'title': 'Manage Tables', 'subtitle': 'Create, merge and manage floor tables'},
        {'id': 'pos_kds', 'title': 'Kitchen Display (KDS)', 'subtitle': 'Access kitchen order display system'},
        {'id': 'pos_takeaway_delivery', 'title': 'Takeaway & Delivery', 'subtitle': 'Handle online and delivery orders'},
      ],
    },
    'products': {
      'label': 'Products & Menu',
      'icon': Icons.inventory_2_outlined,
      'items': [
        {'id': 'products_view', 'title': 'View Products', 'subtitle': 'View items, prices and modifiers'},
        {'id': 'products_add_edit', 'title': 'Add / Edit Products', 'subtitle': 'Create and update menu catalog'},
        {'id': 'products_delete', 'title': 'Delete Products', 'subtitle': 'Remove menu items from store'},
        {'id': 'products_categories', 'title': 'Manage Categories', 'subtitle': 'Organize product categories & images'},
      ],
    },
    'inventory': {
      'label': 'Inventory',
      'icon': Icons.archive_outlined,
      'items': [
        {'id': 'inventory_view', 'title': 'View Stock', 'subtitle': 'Monitor current inventory levels'},
        {'id': 'inventory_adjust', 'title': 'Stock In / Stock Out', 'subtitle': 'Log inventory adjustments and wastage'},
        {'id': 'inventory_alerts', 'title': 'Low Stock Alerts', 'subtitle': 'Receive low inventory notifications'},
        {'id': 'inventory_purchases', 'title': 'Purchase Orders', 'subtitle': 'Manage supplier bills and POs'},
      ],
    },
    'customers': {
      'label': 'Customers & CRM',
      'icon': Icons.people_outline_rounded,
      'items': [
        {'id': 'customers_view', 'title': 'View Customer List', 'subtitle': 'Access directory of customer accounts'},
        {'id': 'customers_add_edit', 'title': 'Add / Edit Customers', 'subtitle': 'Register customer profiles & loyalty'},
        {'id': 'customers_crm', 'title': 'CRM Campaigns', 'subtitle': 'Send promotions via SMS/WhatsApp'},
        {'id': 'customers_khata', 'title': 'Customer Credit / Khata', 'subtitle': 'Manage customer credit ledger'},
      ],
    },
    'reports': {
      'label': 'Reports & Analytics',
      'icon': Icons.insert_chart_outlined_rounded,
      'items': [
        {'id': 'reports_daily_sales', 'title': 'Daily Sales Report', 'subtitle': 'View day-end sales summary'},
        {'id': 'reports_financial', 'title': 'Financial Reports', 'subtitle': 'Access profit/loss and tax breakdowns'},
        {'id': 'reports_export', 'title': 'Export Data', 'subtitle': 'Download reports in Excel and PDF'},
        {'id': 'reports_staff_performance', 'title': 'Staff Performance', 'subtitle': 'Track individual cashier sales'},
      ],
    },
    'settings': {
      'label': 'Settings & Business',
      'icon': Icons.settings_outlined,
      'items': [
        {'id': 'settings_store_profile', 'title': 'Business Profile', 'subtitle': 'Modify store information and branding'},
        {'id': 'settings_printers', 'title': 'Printers & Hardware', 'subtitle': 'Configure thermal printers and KOT'},
        {'id': 'settings_taxes', 'title': 'Tax & Charges', 'subtitle': 'Set GST and service charge rates'},
        {'id': 'settings_payments', 'title': 'Payment Gateways', 'subtitle': 'Configure UPI / QR and POS terminal'},
        {'id': 'settings_staff', 'title': 'Staff Management', 'subtitle': 'Add, edit and manage staff permissions'},
      ],
    },
    'others': {
      'label': 'System & Others',
      'icon': Icons.more_horiz_rounded,
      'items': [
        {'id': 'others_activity_logs', 'title': 'Activity Logs', 'subtitle': 'View security and action audit trail'},
        {'id': 'others_chotu_ai', 'title': 'Chotu AI Assistant', 'subtitle': 'Use Chotu voice and smart assistant'},
        {'id': 'others_offline_mode', 'title': 'Offline Mode', 'subtitle': 'Sync offline orders with cloud'},
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _currentStaff = widget.staff;
    _tabController = TabController(length: 5, vsync: this);

    _nameController = TextEditingController(text: _currentStaff.name);
    _employeeIdController = TextEditingController(text: _currentStaff.employeeId);
    _emailController = TextEditingController(text: _currentStaff.email);
    _phoneController = TextEditingController(text: _currentStaff.phone);
    _salaryController = TextEditingController(
        text: _currentStaff.salary > 0 ? _currentStaff.salary.toStringAsFixed(0) : '');
    _notesController = TextEditingController(text: _currentStaff.notes);
    _pinController = TextEditingController(text: _currentStaff.pin);

    _selectedRole = _roleOptions.contains(_currentStaff.role)
        ? _currentStaff.role
        : 'Manager';
    _selectedDepartment = _departmentOptions.contains(_currentStaff.department)
        ? _currentStaff.department
        : 'Operations';
    _selectedLocation = _locationOptions.contains(_currentStaff.workLocation)
        ? _currentStaff.workLocation
        : 'Main Outlet';
    _selectedReportingTo = _reportingToOptions.contains(_currentStaff.reportingTo)
        ? _currentStaff.reportingTo
        : 'Amit Sharma';
    _selectedShift = _shiftOptions.contains(_currentStaff.shift)
        ? _currentStaff.shift
        : 'Morning Shift (8 AM - 4 PM)';
    _selectedLanguage = _languageOptions.contains(_currentStaff.language)
        ? _currentStaff.language
        : 'English';
    _selectedTheme = _themeOptions.contains(_currentStaff.theme)
        ? _currentStaff.theme
        : 'Light';
    _selectedDefaultScreen = _defaultScreenOptions.contains(_currentStaff.defaultScreen)
        ? _currentStaff.defaultScreen
        : 'Dashboard';

    _enableBiometric = _currentStaff.enableBiometric;
    _isActive = _currentStaff.isActive;
    _forcePasswordChange = _currentStaff.forcePasswordChange;
    _sendWelcomeEmail = _currentStaff.sendWelcomeEmail;
    _joiningDate = _currentStaff.joiningDate ?? DateTime.now();

    _selectedPermissions = Set<String>.from(_currentStaff.permissions);
    if (_selectedPermissions.isEmpty) {
      _applyRolePreset(_selectedRole);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _notesController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _applyRolePreset(String role) {
    final perms = <String>{};
    switch (role.toLowerCase()) {
      case 'admin':
        for (final cat in _permissionCategories.values) {
          final items = cat['items'] as List<Map<String, String>>;
          for (final item in items) {
            perms.add(item['id']!);
          }
        }
        break;
      case 'manager':
        perms.addAll([
          'pos_access',
          'pos_apply_discount',
          'pos_cancel_orders',
          'pos_view_all_orders',
          'pos_manage_tables',
          'pos_takeaway_delivery',
          'products_view',
          'products_add_edit',
          'products_categories',
          'inventory_view',
          'inventory_adjust',
          'inventory_alerts',
          'customers_view',
          'customers_add_edit',
          'customers_crm',
          'reports_daily_sales',
          'reports_financial',
          'reports_export',
          'reports_staff_performance',
          'settings_printers',
          'others_activity_logs',
          'others_chotu_ai',
        ]);
        break;
      case 'cashier':
        perms.addAll([
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
          'others_chotu_ai',
        ]);
        break;
      case 'waiter':
        perms.addAll([
          'pos_access',
          'pos_manage_tables',
          'pos_takeaway_delivery',
          'products_view',
          'others_chotu_ai',
        ]);
        break;
      case 'chef':
        perms.addAll([
          'pos_kds',
          'products_view',
          'inventory_view',
          'inventory_alerts',
        ]);
        break;
      default:
        perms.addAll(['pos_access', 'products_view']);
        break;
    }

    setState(() {
      _selectedPermissions = perms;
    });
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
      debugPrint('[StaffSettingsScreen] Image pick error: $e');
    }
  }

  Future<void> _handleSaveChanges() async {
    if (_formKey.currentState?.validate() != true) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required profile fields correctly.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = _currentStaff.copyWith(
        name: _nameController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        department: _selectedDepartment,
        workLocation: _selectedLocation,
        reportingTo: _selectedReportingTo,
        shift: _selectedShift,
        language: _selectedLanguage,
        theme: _selectedTheme,
        defaultScreen: _selectedDefaultScreen,
        enableBiometric: _enableBiometric,
        status: _isActive ? 'Active' : 'Inactive',
        pin: _pinController.text.trim().isNotEmpty ? _pinController.text.trim() : _currentStaff.pin,
        salary: double.tryParse(_salaryController.text.trim()) ?? _currentStaff.salary,
        notes: _notesController.text.trim(),
        joiningDate: _joiningDate,
        permissions: _selectedPermissions.toList(),
        forcePasswordChange: _forcePasswordChange,
        sendWelcomeEmail: _sendWelcomeEmail,
        updatedAt: DateTime.now(),
      );

      final saved = await _staffService.updateStaff(updated);
      _db.updateStaff(saved ?? updated);

      if (mounted) {
        setState(() {
          _currentStaff = saved ?? updated;
        });

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
                    'Staff profile for "${_currentStaff.name}" updated successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        widget.onStaffUpdated?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[StaffSettingsScreen] Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update staff: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showChangePinDialog() {
    final pinCtrl = TextEditingController(text: _pinController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Change Login PIN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a 4-digit numeric security PIN for quick POS access.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final pin = pinCtrl.text.trim();
              if (pin.length >= 4) {
                setState(() {
                  _pinController.text = pin;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN updated. Remember to save changes.'),
                    backgroundColor: Color(0xFF2563EB),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Set PIN', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteStaff() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Staff Member',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        content: Text(
          'Are you sure you want to delete "${_currentStaff.name}" (${_currentStaff.employeeId})? This action cannot be undone.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _staffService.deleteStaff(_currentStaff.id);
      _db.deleteStaff(_currentStaff.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_currentStaff.name} has been removed.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        widget.onStaffUpdated?.call();
        Navigator.of(context).pop(true);
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
              constraints: const BoxConstraints(maxWidth: 820),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Top Header Bar
                    _buildTopHeader(),
                    const SizedBox(height: 18),

                    // 2. Staff Profile Hero Card
                    _buildHeroHeaderCard(),
                    const SizedBox(height: 16),

                    // 3. Tab Bar Navigation
                    _buildCustomTabBar(),
                    const SizedBox(height: 16),

                    // 4. Tab Content Container
                    _buildActiveTabContent(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. Top Header Bar ---
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back Button + Title + Subtitle
        Expanded(
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E40AF), size: 20),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Settings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Update staff information, permissions and preferences',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // "+ Save Changes" Solid Blue Button
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _handleSaveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded, size: 20),
          label: Text(
            _isSaving ? 'Saving...' : 'Save Changes',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          ),
        ),
      ],
    );
  }

  // --- 2. Staff Profile Hero Card (Exact Match to Image) ---
  Widget _buildHeroHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Large Avatar with Camera Badge
          GestureDetector(
            onTap: _pickAvatarImage,
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                    image: _avatarImageFile != null
                        ? DecorationImage(
                            image: FileImage(_avatarImageFile!),
                            fit: BoxFit.cover,
                          )
                        : (_currentStaff.avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_currentStaff.avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null),
                  ),
                  child: (_avatarImageFile == null && _currentStaff.avatarUrl.isEmpty)
                      ? Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _currentStaff.initials,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Details on Right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Active Pill + Role Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text : _currentStaff.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Active / Inactive Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Role Pill (Soft purple background from mockup)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedRole,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Employee ID
                Text(
                  _employeeIdController.text.isNotEmpty
                      ? _employeeIdController.text
                      : _currentStaff.employeeId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // Email & Phone Row
                Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _emailController.text.isNotEmpty
                            ? _emailController.text
                            : (_currentStaff.email.isNotEmpty ? _currentStaff.email : 'No email added'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _phoneController.text.isNotEmpty
                            ? _phoneController.text
                            : (_currentStaff.phone.isNotEmpty ? _currentStaff.phone : 'No phone added'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Reports to Row
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Reports to: $_selectedReportingTo',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
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

  // --- 3. Custom Tab Bar Navigation ---
  Widget _buildCustomTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        indicatorColor: const Color(0xFF2563EB),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        tabs: const [
          Tab(
            icon: Icon(Icons.person_outline_rounded, size: 19),
            text: 'Profile',
            iconMargin: EdgeInsets.only(bottom: 4),
          ),
          Tab(
            icon: Icon(Icons.tune_rounded, size: 19),
            text: 'Permissions',
            iconMargin: EdgeInsets.only(bottom: 4),
          ),
          Tab(
            icon: Icon(Icons.laptop_mac_rounded, size: 19),
            text: 'Work Settings',
            iconMargin: EdgeInsets.only(bottom: 4),
          ),
          Tab(
            icon: Icon(Icons.shield_outlined, size: 19),
            text: 'Security',
            iconMargin: EdgeInsets.only(bottom: 4),
          ),
          Tab(
            icon: Icon(Icons.notifications_none_rounded, size: 19),
            text: 'Activity',
            iconMargin: EdgeInsets.only(bottom: 4),
          ),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  // --- 4. Active Tab Content ---
  Widget _buildActiveTabContent() {
    switch (_tabController.index) {
      case 0:
        return _buildProfileTab();
      case 1:
        return _buildPermissionsTab();
      case 2:
        return _buildWorkSettingsTab();
      case 3:
        return _buildSecurityTab();
      case 4:
        return _buildActivityTab();
      default:
        return _buildProfileTab();
    }
  }

  // ==================== TAB 0: PROFILE (MATCHING EXACT SCREENSHOT) ====================
  Widget _buildProfileTab() {
    return Column(
      children: [
        // 1. Personal Information Card
        _buildSectionCard(
          icon: Icons.person_outline_rounded,
          title: 'Personal Information',
          trailing: OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'Full Name *',
                      controller: _nameController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Employee ID',
                      controller: _employeeIdController,
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'Email Address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Mobile Number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Work Information Card
        _buildSectionCard(
          icon: Icons.group_outlined,
          title: 'Work Information',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Role *',
                      value: _selectedRole,
                      items: _roleOptions,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRole = val);
                          _applyRolePreset(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Department',
                      value: _selectedDepartment,
                      items: _departmentOptions,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDepartment = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Work Location',
                      value: _selectedLocation,
                      items: _locationOptions,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLocation = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Reporting To',
                      value: _selectedReportingTo,
                      items: _reportingToOptions,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedReportingTo = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Preferences Card
        _buildSectionCard(
          icon: Icons.shield_outlined,
          title: 'Preferences',
          child: Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Language',
                  value: _selectedLanguage,
                  items: _languageOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLanguage = val);
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDropdownField(
                  label: 'Theme',
                  value: _selectedTheme,
                  items: _themeOptions,
                  prefixIcon: Icons.wb_sunny_outlined,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedTheme = val);
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDropdownField(
                  label: 'Default Screen',
                  value: _selectedDefaultScreen,
                  items: _defaultScreenOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDefaultScreen = val);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Login & Security Card
        _buildSectionCard(
          icon: Icons.shield_outlined,
          title: 'Login & Security',
          child: Row(
            children: [
              // Change PIN
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change PIN',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Update login PIN',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _showChangePinDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Change PIN', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Biometric Login Switch
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biometric Login',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Use fingerprint for faster login',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableBiometric,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _enableBiometric = val),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Account Status Card
        _buildSectionCard(
          icon: Icons.info_outline_rounded,
          title: 'Account Status',
          child: Row(
            children: [
              // Status Toggle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Switch(
                          value: _isActive,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isActive ? 'Active' : 'Inactive',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const Text(
                                'Staff member can login and access the system',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Last Login Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last Login', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(_currentStaff.updatedAt ?? DateTime.now()),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 5),
                                  const Flexible(
                                    child: Text(
                                      'From Windows • Noida, India',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 6. Delete Staff Card (Exact Red Container from Screenshot)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFECACA), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Staff',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Permanently remove this staff member from the system',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF7F1D1D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _handleDeleteStaff,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 1: DYNAMIC PERMISSIONS ====================
  Widget _buildPermissionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role Preset Quick Selector Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dynamic Permissions Matrix',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Customize granular access or apply role template presets',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Role Presets:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  ...['Admin', 'Manager', 'Cashier', 'Waiter', 'Chef'].map((r) {
                    final isCurrent = _selectedRole.toLowerCase() == r.toLowerCase();
                    return ActionChip(
                      label: Text(r, style: TextStyle(fontSize: 12, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600)),
                      backgroundColor: isCurrent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      side: BorderSide(color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                      onPressed: () => _applyRolePreset(r),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Permission Categories List
        ..._permissionCategories.entries.map((entry) {
          final catId = entry.key;
          final catData = entry.value;
          final label = catData['label'] as String;
          final icon = catData['icon'] as IconData;
          final items = catData['items'] as List<Map<String, String>>;

          final allCategorySelected = items.every((i) => _selectedPermissions.contains(i['id']));

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: const Color(0xFF2563EB), size: 19),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (allCategorySelected) {
                            for (final item in items) {
                              _selectedPermissions.remove(item['id']);
                            }
                          } else {
                            for (final item in items) {
                              _selectedPermissions.add(item['id']!);
                            }
                          }
                        });
                      },
                      child: Text(
                        allCategorySelected ? 'Deselect All' : 'Select All',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 20),

                // Granular Permission Items
                ...items.map((item) {
                  final pId = item['id']!;
                  final isChecked = _selectedPermissions.contains(pId);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']!,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item['subtitle']!,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isChecked,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) {
                            setState(() {
                              if (val) {
                                _selectedPermissions.add(pId);
                              } else {
                                _selectedPermissions.remove(pId);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==================== TAB 2: WORK SETTINGS ====================
  Widget _buildWorkSettingsTab() {
    return Column(
      children: [
        _buildSectionCard(
          icon: Icons.work_history_outlined,
          title: 'Shift & Compensation',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Assigned Shift',
                      value: _selectedShift,
                      items: _shiftOptions,
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedShift = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Monthly Salary / Pay (₹)',
                      controller: _salaryController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Joining Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _joiningDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _joiningDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _joiningDate != null
                                      ? DateFormat('dd MMM yyyy').format(_joiningDate!)
                                      : 'Select date',
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                ),
                                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 14),
              _buildInputField(
                label: 'Notes & Internal Comments',
                controller: _notesController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 3: SECURITY ====================
  Widget _buildSecurityTab() {
    return Column(
      children: [
        _buildSectionCard(
          icon: Icons.security_rounded,
          title: 'Security & Access Control',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'POS Login PIN (4 Digits)',
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: OutlinedButton.icon(
                        onPressed: _showChangePinDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                        icon: const Icon(Icons.pin_rounded, size: 18),
                        label: const Text('Reset PIN', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Force Password Change on Next Login', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Requires user to set a new password when signing in', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  value: _forcePasswordChange,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setState(() => _forcePasswordChange = v),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Send Welcome Email with Credentials', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Dispatches onboarding instructions and login link', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  value: _sendWelcomeEmail,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setState(() => _sendWelcomeEmail = v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 4: ACTIVITY ====================
  Widget _buildActivityTab() {
    final activities = [
      {'title': 'Logged into Windows POS Counter', 'time': 'Today, 10:42 AM', 'icon': Icons.login_rounded, 'color': const Color(0xFF16A34A)},
      {'title': 'Completed Order #20260922-004 (₹420)', 'time': 'Today, 10:15 AM', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF2563EB)},
      {'title': 'Printed KOT for Table T-02', 'time': 'Today, 09:50 AM', 'icon': Icons.print_rounded, 'color': const Color(0xFF7C3AED)},
      {'title': 'Applied ₹50 Promo Discount on Bill', 'time': 'Yesterday, 08:30 PM', 'icon': Icons.local_offer_outlined, 'color': const Color(0xFFEA580C)},
      {'title': 'Shift Opened: Morning Shift (8 AM - 4 PM)', 'time': 'Yesterday, 08:00 AM', 'icon': Icons.schedule_rounded, 'color': const Color(0xFF0284C7)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Staff Activity & Audit Trail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          const Text('Recent actions and POS events executed by this staff member', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          ...activities.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: (a['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['title'] as String, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          Text(a['time'] as String, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- Reusable Widget Builders ---
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF334155)),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    IconData? prefixIcon,
    required void Function(String?) onChanged,
  }) {
    final cleanValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: cleanValue,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
          items: items
              .map((it) => DropdownMenuItem(
                    value: it,
                    child: Text(it, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}