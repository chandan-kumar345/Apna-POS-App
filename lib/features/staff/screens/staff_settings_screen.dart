import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/services/staff_service.dart';
import '../../../core/services/upload_service.dart';

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

  // Dynamic Lists of Options
  List<String> _roleOptions = [
    'Admin',
    'Manager',
    'Cashier',
    'Sales',
    'Inventory',
    'Support',
    'Chef',
    'Waiter',
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

  List<String> _reportingToOptions = [
    'Store Owner / Admin',
    'None',
  ];

  List<String> _locationOptions = [
    'Main Branch',
    'Counter 1',
    'Kitchen',
    'Outlet 1',
    'Takeaway Counter',
    'Floor 1',
    'Floor 2',
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
    'Sales Report',
    'CRM Customers',
    'Inventory',
  ];

  // 12 Navigation Sidebar Categories for Permissions
  final List<Map<String, dynamic>> _permissionCategories = [
    {
      'id': 'dashboard',
      'label': 'Dashboard',
      'icon': Icons.home_rounded,
      'items': [
        {'id': 'dashboard_view', 'title': 'View Dashboard & Summary', 'subtitle': 'View sales metrics, total revenues & statistics'},
        {'id': 'dashboard_realtime', 'title': 'Real-time Sales Tracking', 'subtitle': 'Track live orders counter and revenue stream'},
        {'id': 'dashboard_quick_actions', 'title': 'Access Quick Actions', 'subtitle': 'Use dashboard shortcut buttons and fast actions'},
        {'id': 'dashboard_recent_activity', 'title': 'Live Activity Stream', 'subtitle': 'View recent customer orders and floor updates'},
      ],
    },
    {
      'id': 'pos',
      'label': 'POS Billing',
      'icon': Icons.point_of_sale_rounded,
      'items': [
        {'id': 'pos_access', 'title': 'Access POS Billing', 'subtitle': 'Allow opening billing register and cart checkout'},
        {'id': 'pos_create_order', 'title': 'Create & Place Orders', 'subtitle': 'Punch dine-in, takeaway, and delivery bills'},
        {'id': 'pos_apply_discount', 'title': 'Apply Bill Discounts', 'subtitle': 'Allow item and bill-level discount coupons'},
        {'id': 'pos_apply_tax', 'title': 'Modify Tax & Charges', 'subtitle': 'Adjust GST rates, service charges & fees'},
        {'id': 'pos_cancel_orders', 'title': 'Cancel / Void Orders', 'subtitle': 'Allow cancelling orders and voiding billed items'},
        {'id': 'pos_refund', 'title': 'Issue Refunds & Returns', 'subtitle': 'Process customer payment refunds and returns'},
        {'id': 'pos_split_bill', 'title': 'Split Bills & Merge', 'subtitle': 'Split checks between customers and merge tables'},
        {'id': 'pos_custom_items', 'title': 'Custom Price Items', 'subtitle': 'Add open-priced custom products on-the-fly'},
        {'id': 'pos_print_receipt', 'title': 'Print & Re-print Bills', 'subtitle': 'Print thermal receipts and invoice duplicates'},
        {'id': 'pos_takeaway_delivery', 'title': 'Takeaway & Delivery', 'subtitle': 'Handle online orders, takeaways & delivery'},
      ],
    },
    {
      'id': 'tables',
      'label': 'Tables & Floor',
      'icon': Icons.table_restaurant_rounded,
      'items': [
        {'id': 'tables_view', 'title': 'View Dining Tables', 'subtitle': 'View live floor tables status and occupancy'},
        {'id': 'tables_manage', 'title': 'Manage Tables & Floor', 'subtitle': 'Create, edit, rename and arrange dining tables'},
        {'id': 'tables_transfer', 'title': 'Transfer & Merge Tables', 'subtitle': 'Shift running orders between tables and merge'},
        {'id': 'tables_reservation', 'title': 'Manage Reservations', 'subtitle': 'Reserve and schedule tables for upcoming guests'},
      ],
    },
    {
      'id': 'orders',
      'label': 'My Orders & KDS',
      'icon': Icons.receipt_long_rounded,
      'items': [
        {'id': 'orders_view', 'title': 'View Orders Directory', 'subtitle': 'Browse all live, pending and completed orders'},
        {'id': 'orders_edit', 'title': 'Edit Running Orders', 'subtitle': 'Add more items and update kitchen instructions'},
        {'id': 'orders_status_update', 'title': 'Update Order Status', 'subtitle': 'Mark orders as Preparing, Ready, Served, Done'},
        {'id': 'orders_kds', 'title': 'Kitchen Display (KDS)', 'subtitle': 'Access digital kitchen order display system'},
        {'id': 'orders_kot', 'title': 'Print & Re-print KOT', 'subtitle': 'Send and re-print Kitchen Order Tickets'},
      ],
    },
    {
      'id': 'menu',
      'label': 'Menu & Catalog',
      'icon': Icons.dinner_dining_rounded,
      'items': [
        {'id': 'menu_view', 'title': 'View Menu Catalog', 'subtitle': 'Browse food catalog, prices and categories'},
        {'id': 'menu_add', 'title': 'Add New Dishes', 'subtitle': 'Create new menu items with images and prices'},
        {'id': 'menu_edit', 'title': 'Edit Menu & Pricing', 'subtitle': 'Update prices, descriptions and modifiers'},
        {'id': 'menu_delete', 'title': 'Delete / Archive Items', 'subtitle': 'Remove dishes from catalog or archive'},
        {'id': 'menu_categories', 'title': 'Manage Categories', 'subtitle': 'Create, reorder and organize categories'},
        {'id': 'menu_availability', 'title': 'Item Availability (86)', 'subtitle': 'Toggle items in-stock or out of stock instantly'},
      ],
    },
    {
      'id': 'inventory',
      'label': 'Inventory',
      'icon': Icons.inventory_2_rounded,
      'items': [
        {'id': 'inventory_view', 'title': 'View Raw Stock Levels', 'subtitle': 'Monitor ingredients quantity and stock values'},
        {'id': 'inventory_adjust', 'title': 'Stock In / Stock Out', 'subtitle': 'Log manual stock additions and inward batches'},
        {'id': 'inventory_wastage', 'title': 'Log Stock Wastage', 'subtitle': 'Record damaged, expired or wasted inventory'},
        {'id': 'inventory_alerts', 'title': 'Low Stock Alerts', 'subtitle': 'Receive low inventory and threshold warnings'},
        {'id': 'inventory_purchases', 'title': 'Purchase Orders & Vendors', 'subtitle': 'Manage supplier invoices and purchase orders'},
      ],
    },
    {
      'id': 'reports',
      'label': 'Sales Report',
      'icon': Icons.bar_chart_rounded,
      'items': [
        {'id': 'reports_view_own', 'title': 'View Own Sales Summary', 'subtitle': 'Track own shift cash collections and bills'},
        {'id': 'reports_daily_sales', 'title': 'Daily Sales Report', 'subtitle': 'View total store day-end sales summary'},
        {'id': 'reports_financial', 'title': 'Financials & Tax Breakdown', 'subtitle': 'Access profit/loss, GST tax reports and margins'},
        {'id': 'reports_item_sales', 'title': 'Item-wise Sales Analytics', 'subtitle': 'Analyze bestsellers and category sales performance'},
        {'id': 'reports_export', 'title': 'Export Data (Excel & PDF)', 'subtitle': 'Download sales reports in Excel and PDF formats'},
        {'id': 'reports_staff_performance', 'title': 'Staff Sales Performance', 'subtitle': 'Track sales generated per cashier / staff member'},
      ],
    },
    {
      'id': 'crm',
      'label': 'CRM Customers',
      'icon': Icons.people_alt_rounded,
      'items': [
        {'id': 'crm_view', 'title': 'View Customer Directory', 'subtitle': 'Access customer accounts and order histories'},
        {'id': 'crm_add_edit', 'title': 'Add & Edit Customers', 'subtitle': 'Register customer details, phones and addresses'},
        {'id': 'crm_delete', 'title': 'Delete Customer Records', 'subtitle': 'Remove duplicate or obsolete customer records'},
        {'id': 'crm_khata', 'title': 'Customer Khata / Credit Ledger', 'subtitle': 'Manage customer credit balances and payments'},
        {'id': 'crm_tags', 'title': 'Customer Tags & Segments', 'subtitle': 'Tag VIP and regular customers for promotions'},
      ],
    },
    {
      'id': 'loyalty',
      'label': 'Loyalty Program',
      'icon': Icons.card_giftcard_rounded,
      'items': [
        {'id': 'loyalty_view', 'title': 'View Loyalty Members', 'subtitle': 'Check customer loyalty points and tier status'},
        {'id': 'loyalty_reward', 'title': 'Issue Points & Stamps', 'subtitle': 'Award loyalty points on purchases and stamp cards'},
        {'id': 'loyalty_redeem', 'title': 'Redeem Loyalty Points', 'subtitle': 'Apply loyalty points for bill discounts'},
        {'id': 'loyalty_manage_tiers', 'title': 'Configure Loyalty Rules', 'subtitle': 'Set point conversion rates and tier thresholds'},
      ],
    },
    {
      'id': 'campaign',
      'label': 'Campaigns',
      'icon': Icons.campaign_rounded,
      'items': [
        {'id': 'campaign_view', 'title': 'View Marketing Campaigns', 'subtitle': 'Track promotional campaign performance & ROI'},
        {'id': 'campaign_create', 'title': 'Create SMS / WhatsApp Blasts', 'subtitle': 'Draft and launch marketing messages'},
        {'id': 'campaign_templates', 'title': 'Manage Message Templates', 'subtitle': 'Customize festival offers and discount coupons'},
        {'id': 'campaign_broadcast', 'title': 'Instant Flash Broadcast', 'subtitle': 'Send real-time alerts to customer segments'},
      ],
    },
    {
      'id': 'staff',
      'label': 'Staff Setting',
      'icon': Icons.badge_rounded,
      'items': [
        {'id': 'staff_view', 'title': 'View Staff Directory', 'subtitle': 'Browse team members, roles, and active status'},
        {'id': 'staff_add', 'title': 'Create New Staff', 'subtitle': 'Add employee accounts with login credentials'},
        {'id': 'staff_edit', 'title': 'Edit Staff & Permissions', 'subtitle': 'Update employee roles, PINs, and access rights'},
        {'id': 'staff_delete', 'title': 'Deactivate / Remove Staff', 'subtitle': 'Disable or delete staff accounts'},
        {'id': 'staff_shifts', 'title': 'Manage Shifts & Duty', 'subtitle': 'Assign work schedules and shift timings'},
      ],
    },
    {
      'id': 'settings',
      'label': 'Business Setting',
      'icon': Icons.settings_rounded,
      'items': [
        {'id': 'settings_profile', 'title': 'Store & Business Profile', 'subtitle': 'Edit store name, logo, contact, and address'},
        {'id': 'settings_branches', 'title': 'Business Branches', 'subtitle': 'Manage multi-branch outlets and counters'},
        {'id': 'settings_printers', 'title': 'Printers & Hardware', 'subtitle': 'Configure Bluetooth, USB, Thermal, and KOT printers'},
        {'id': 'settings_taxes', 'title': 'Taxes & Service Charges', 'subtitle': 'Configure GST, VAT, service charges and packaging'},
        {'id': 'settings_payments', 'title': 'Payment Gateways & UPI QR', 'subtitle': 'Configure Razorpay, UPI QR, and payment terminals'},
        {'id': 'settings_receipt_template', 'title': 'Receipt Customization', 'subtitle': 'Customize bill headers, footers, and logo'},
        {'id': 'settings_chotu_ai', 'title': 'Chotu AI Voice Assistant', 'subtitle': 'Configure smart voice order taking and prompts'},
      ],
    },
  ];

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

    _initDynamicOptions();

    _selectedLanguage = _languageOptions.firstWhere(
      (l) => l.toLowerCase() == _currentStaff.language.toLowerCase(),
      orElse: () => 'English',
    );

    _selectedTheme = _themeOptions.firstWhere(
      (t) => t.toLowerCase() == _currentStaff.theme.toLowerCase(),
      orElse: () => 'Light',
    );

    _selectedDefaultScreen = _defaultScreenOptions.firstWhere(
      (d) => d.toLowerCase() == _currentStaff.defaultScreen.toLowerCase(),
      orElse: () => 'Dashboard',
    );

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

  void _initDynamicOptions() {
    // 1. Dynamic Roles
    _roleOptions = List<String>.from(_db.allStaffRoles);
    if (_currentStaff.role.isNotEmpty && !_roleOptions.contains(_currentStaff.role)) {
      _roleOptions.add(_currentStaff.role);
    }
    _selectedRole = _roleOptions.firstWhere(
      (r) => r.toLowerCase() == _currentStaff.role.toLowerCase(),
      orElse: () => _roleOptions.firstWhere((r) => r.toLowerCase() == 'cashier', orElse: () => _roleOptions.first),
    );

    // 2. Dynamic Department
    _selectedDepartment = _departmentOptions.firstWhere(
      (d) => d.toLowerCase() == _currentStaff.department.toLowerCase(),
      orElse: () => _departmentOptions.first,
    );

    // 3. Dynamic Business Branches
    _locationOptions = List<String>.from(_db.allBusinessBranches);
    if (_currentStaff.workLocation.isNotEmpty && !_locationOptions.contains(_currentStaff.workLocation)) {
      _locationOptions.add(_currentStaff.workLocation);
    }
    _selectedLocation = _locationOptions.firstWhere(
      (l) => l.toLowerCase() == _currentStaff.workLocation.toLowerCase(),
      orElse: () => _locationOptions.first,
    );

    // 4. Dynamic Reporting To (Store Owner + Other Staff Members)
    final ownerName = _db.restaurant?.name.trim().isNotEmpty == true
        ? _db.restaurant!.name.trim()
        : (_db.currentUser?.name.trim().isNotEmpty == true ? _db.currentUser!.name.trim() : 'Store Owner');
    final ownerOption = 'Store Owner / Admin ($ownerName)';

    final List<String> reportingList = [ownerOption];
    for (final s in _db.staffList) {
      if (s.id != _currentStaff.id) {
        final staffOption = '${s.name} (${s.role} • ${s.employeeId.isNotEmpty ? s.employeeId : 'Staff'})';
        if (!reportingList.contains(staffOption)) {
          reportingList.add(staffOption);
        }
      }
    }
    if (!reportingList.contains('None')) {
      reportingList.add('None');
    }
    _reportingToOptions = reportingList;

    _selectedReportingTo = _reportingToOptions.firstWhere(
      (r) => r.toLowerCase().contains(_currentStaff.reportingTo.toLowerCase()) ||
          _currentStaff.reportingTo.toLowerCase().contains(r.toLowerCase()),
      orElse: () => _reportingToOptions.first,
    );

    // 5. Shift
    _selectedShift = _shiftOptions.firstWhere(
      (s) => s.toLowerCase() == _currentStaff.shift.toLowerCase(),
      orElse: () => _shiftOptions.first,
    );
  }

  void _showAddRoleDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_moderator_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Add Custom Role', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the title for the new staff role (e.g. Floor Supervisor, Bartender, Delivery Lead).',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. Floor Supervisor',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newRole = textController.text.trim();
              if (newRole.isNotEmpty) {
                Navigator.pop(ctx);
                await _db.addCustomRole(newRole);
                if (mounted) {
                  setState(() {
                    _roleOptions = List<String>.from(_db.allStaffRoles);
                    _selectedRole = newRole;
                    _applyRolePreset(newRole);
                  });
                }
              }
            },
            child: const Text('Add Role', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddBranchDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_business_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Add Business Branch', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the name or identifier of the new business branch / outlet location.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. Downtown Outlet, Highway Branch',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newBranch = textController.text.trim();
              if (newBranch.isNotEmpty) {
                Navigator.pop(ctx);
                await _db.addBusinessBranch(newBranch);
                if (mounted) {
                  setState(() {
                    _locationOptions = List<String>.from(_db.allBusinessBranches);
                    _selectedLocation = newBranch;
                  });
                }
              }
            },
            child: const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
        for (final cat in _permissionCategories) {
          final items = cat['items'] as List<Map<String, String>>;
          for (final item in items) {
            perms.add(item['id']!);
          }
        }
        break;
      case 'manager':
        perms.addAll([
          'dashboard_view',
          'dashboard_realtime',
          'dashboard_quick_actions',
          'dashboard_recent_activity',
          'pos_access',
          'pos_create_order',
          'pos_apply_discount',
          'pos_apply_tax',
          'pos_cancel_orders',
          'pos_refund',
          'pos_split_bill',
          'pos_custom_items',
          'pos_print_receipt',
          'pos_takeaway_delivery',
          'tables_view',
          'tables_manage',
          'tables_transfer',
          'tables_reservation',
          'orders_view',
          'orders_edit',
          'orders_status_update',
          'orders_kds',
          'orders_kot',
          'menu_view',
          'menu_add',
          'menu_edit',
          'menu_categories',
          'menu_availability',
          'inventory_view',
          'inventory_adjust',
          'inventory_wastage',
          'inventory_alerts',
          'inventory_purchases',
          'reports_view_own',
          'reports_daily_sales',
          'reports_financial',
          'reports_item_sales',
          'reports_export',
          'reports_staff_performance',
          'crm_view',
          'crm_add_edit',
          'crm_khata',
          'crm_tags',
          'loyalty_view',
          'loyalty_reward',
          'loyalty_redeem',
          'campaign_view',
          'campaign_create',
          'staff_view',
          'staff_shifts',
          'settings_printers',
        ]);
        break;
      case 'cashier':
        perms.addAll([
          'pos_access',
          'pos_create_order',
          'pos_apply_discount',
          'pos_split_bill',
          'pos_custom_items',
          'pos_print_receipt',
          'pos_takeaway_delivery',
          'tables_view',
          'orders_view',
          'orders_status_update',
          'menu_view',
          'menu_availability',
          'crm_view',
          'crm_add_edit',
          'crm_khata',
          'reports_view_own',
          'loyalty_view',
          'loyalty_redeem',
        ]);
        break;
      case 'waiter':
        perms.addAll([
          'pos_create_order',
          'pos_takeaway_delivery',
          'tables_view',
          'tables_transfer',
          'orders_view',
          'orders_edit',
          'orders_status_update',
          'orders_kot',
          'menu_view',
          'menu_availability',
        ]);
        break;
      case 'chef':
      case 'kitchen':
        perms.addAll([
          'orders_view',
          'orders_status_update',
          'orders_kds',
          'orders_kot',
          'menu_view',
          'menu_availability',
          'inventory_view',
          'inventory_alerts',
        ]);
        break;
      case 'inventory':
        perms.addAll([
          'dashboard_view',
          'inventory_view',
          'inventory_adjust',
          'inventory_wastage',
          'inventory_alerts',
          'inventory_purchases',
          'menu_view',
          'menu_categories',
          'menu_availability',
        ]);
        break;
      case 'sales':
        perms.addAll([
          'pos_access',
          'pos_create_order',
          'pos_apply_discount',
          'pos_print_receipt',
          'crm_view',
          'crm_add_edit',
          'crm_khata',
          'crm_tags',
          'loyalty_view',
          'loyalty_reward',
          'campaign_view',
          'campaign_create',
          'reports_view_own',
          'reports_daily_sales',
        ]);
        break;
      case 'support':
        perms.addAll([
          'crm_view',
          'crm_add_edit',
          'crm_khata',
          'orders_view',
          'reports_view_own',
        ]);
        break;
      default:
        perms.addAll([
          'pos_access',
          'pos_create_order',
          'pos_apply_discount',
          'pos_print_receipt',
          'menu_view',
        ]);
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
      // Cloudflare R2 Upload if new image was picked
      String remoteAvatarUrl = _currentStaff.avatarUrl;
      if (_avatarImageFile != null) {
        try {
          final uploaded = await UploadService().uploadImage(_avatarImageFile!, folder: 'profiles');
          if (uploaded != null && uploaded.isNotEmpty) {
            remoteAvatarUrl = uploaded;
            debugPrint('[StaffSettingsScreen] Staff avatar uploaded to Cloudflare R2: $remoteAvatarUrl');
          }
        } catch (uploadErr) {
          debugPrint('[StaffSettingsScreen] Cloudflare R2 upload error: $uploadErr');
        }
        if (remoteAvatarUrl.isEmpty || remoteAvatarUrl == _currentStaff.avatarUrl) {
          try {
            final bytes = await _avatarImageFile!.readAsBytes();
            if (bytes.isNotEmpty) {
              remoteAvatarUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            }
          } catch (_) {
            remoteAvatarUrl = _avatarImageFile!.path;
          }
        }
      }

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
        avatarUrl: remoteAvatarUrl,
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 20),
            SizedBox(width: 8),
            Text('Change Login PIN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a 4-digit numeric security PIN for quick POS access.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(fontSize: 18, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            child: const Text('Set PIN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteStaff() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Staff Member',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
        content: Text(
          'Are you sure you want to delete "${_currentStaff.name}" (${_currentStaff.employeeId})? This action cannot be undone.',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        canvasColor: Colors.white,
        cardColor: Colors.white,
        dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF2563EB);
            }
            return const Color(0xFF94A3B8);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF93C5FD);
            }
            return const Color(0xFFE2E8F0);
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF0F172A),
          displayColor: const Color(0xFF0F172A),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 12 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top Header Bar
                      _buildTopHeader(isMobile),
                      SizedBox(height: isMobile ? 12 : 18),

                      // 2. Staff Profile Hero Card
                      _buildHeroHeaderCard(isMobile),
                      SizedBox(height: isMobile ? 12 : 16),

                      // 3. Tab Bar Navigation
                      _buildCustomTabBar(isMobile),
                      SizedBox(height: isMobile ? 12 : 16),

                      // 4. Tab Content Container
                      _buildActiveTabContent(isMobile),
                      SizedBox(height: isMobile ? 20 : 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. Top Header Bar ---
  Widget _buildTopHeader(bool isMobile) {
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
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: isMobile ? 32 : 38,
                  height: isMobile ? 32 : 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: const Color(0xFF1E40AF),
                    size: isMobile ? 17 : 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Settings',
                      style: TextStyle(
                        fontSize: isMobile ? 16.5 : 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isMobile) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Update staff information, permissions and preferences',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // "+ Save Changes" Solid Blue Button
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _handleSaveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20,
              vertical: isMobile ? 8 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Icon(Icons.check_rounded, size: isMobile ? 15 : 18),
          label: Text(
            _isSaving ? 'Saving...' : 'Save Changes',
            style: TextStyle(
              fontSize: isMobile ? 11.5 : 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. Staff Profile Hero Card ---
  Widget _buildHeroHeaderCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with Camera Badge
          GestureDetector(
            onTap: _pickAvatarImage,
            child: Stack(
              children: [
                Container(
                  width: isMobile ? 56 : 96,
                  height: isMobile ? 56 : 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: isMobile ? 1.5 : 2),
                    image: () {
                      if (_avatarImageFile != null) {
                        return DecorationImage(image: FileImage(_avatarImageFile!), fit: BoxFit.cover);
                      }
                      final url = _currentStaff.avatarUrl.trim();
                      if (url.isEmpty) return null;
                      if (url.startsWith('http://') || url.startsWith('https://')) {
                        return DecorationImage(image: NetworkImage(url), fit: BoxFit.cover);
                      }
                      if (url.startsWith('assets/')) {
                        return DecorationImage(image: AssetImage(url), fit: BoxFit.cover);
                      }
                      if (url.startsWith('data:image') || (url.length > 50 && !url.startsWith('/') && !url.contains('\\'))) {
                        try {
                          final clean = url.contains(',') ? url.split(',').last : url;
                          return DecorationImage(image: MemoryImage(base64Decode(clean.trim())), fit: BoxFit.cover);
                        } catch (_) {}
                      }
                      if (!url.contains('_selected') && File(url).existsSync()) {
                        return DecorationImage(image: FileImage(File(url)), fit: BoxFit.cover);
                      }
                      return null;
                    }(),
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
                              style: TextStyle(
                                fontSize: isMobile ? 19 : 32,
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
                    padding: EdgeInsets.all(isMobile ? 4 : 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: isMobile ? 1.5 : 2.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Icon(Icons.camera_alt_rounded, size: isMobile ? 10 : 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isMobile ? 12 : 20),

          // Details on Right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : _currentStaff.name,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Active / Inactive Pill
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 7 : 10,
                        vertical: isMobile ? 2 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: _isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: isMobile ? 5 : 6,
                            height: isMobile ? 5 : 6,
                            decoration: BoxDecoration(
                              color: _isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Role Pill
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 2 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedRole,
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Employee ID
                Text(
                  _employeeIdController.text.isNotEmpty
                      ? _employeeIdController.text
                      : _currentStaff.employeeId,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 8),

                // Email & Phone
                if (isMobile) ...[
                  Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _emailController.text.isNotEmpty
                              ? _emailController.text
                              : (_currentStaff.email.isNotEmpty ? _currentStaff.email : 'No email added'),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _phoneController.text.isNotEmpty
                              ? _phoneController.text
                              : (_currentStaff.phone.isNotEmpty ? _currentStaff.phone : 'No phone added'),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
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
                ],
                SizedBox(height: isMobile ? 3 : 6),

                // Reports to Row
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: isMobile ? 12 : 15, color: const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Reports to: $_selectedReportingTo',
                        style: TextStyle(
                          fontSize: isMobile ? 10.5 : 13,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
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
    );
  }

  // --- 3. Custom Tab Bar Navigation ---
  Widget _buildCustomTabBar(bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: TextStyle(fontSize: isMobile ? 11.5 : 14, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontSize: isMobile ? 11.5 : 14, fontWeight: FontWeight.w600),
        indicatorColor: const Color(0xFF2563EB),
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        tabs: [
          Tab(
            icon: Icon(Icons.person_outline_rounded, size: isMobile ? 16 : 19),
            text: 'Profile',
            iconMargin: const EdgeInsets.only(bottom: 3),
          ),
          Tab(
            icon: Icon(Icons.tune_rounded, size: isMobile ? 16 : 19),
            text: 'Permissions',
            iconMargin: const EdgeInsets.only(bottom: 3),
          ),
          Tab(
            icon: Icon(Icons.laptop_mac_rounded, size: isMobile ? 16 : 19),
            text: 'Work Settings',
            iconMargin: const EdgeInsets.only(bottom: 3),
          ),
          Tab(
            icon: Icon(Icons.shield_outlined, size: isMobile ? 16 : 19),
            text: 'Security',
            iconMargin: const EdgeInsets.only(bottom: 3),
          ),
          Tab(
            icon: Icon(Icons.notifications_none_rounded, size: isMobile ? 16 : 19),
            text: 'Activity',
            iconMargin: const EdgeInsets.only(bottom: 3),
          ),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  // --- 4. Active Tab Content ---
  Widget _buildActiveTabContent(bool isMobile) {
    switch (_tabController.index) {
      case 0:
        return _buildProfileTab(isMobile);
      case 1:
        return _buildPermissionsTab(isMobile);
      case 2:
        return _buildWorkSettingsTab(isMobile);
      case 3:
        return _buildSecurityTab(isMobile);
      case 4:
        return _buildActivityTab(isMobile);
      default:
        return _buildProfileTab(isMobile);
    }
  }

  // ==================== TAB 0: PROFILE ====================
  Widget _buildProfileTab(bool isMobile) {
    return Column(
      children: [
        // 1. Personal Information Card
        _buildSectionCard(
          isMobile: isMobile,
          icon: Icons.person_outline_rounded,
          title: 'Personal Information',
          trailing: OutlinedButton.icon(
            onPressed: () {
              _tabController.animateTo(0);
              _nameController.selection = TextSelection(baseOffset: 0, extentOffset: _nameController.text.length);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 12,
                vertical: isMobile ? 4 : 8,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(Icons.edit_outlined, size: isMobile ? 13 : 15),
            label: Text('Edit', style: TextStyle(fontSize: isMobile ? 11 : 12.5, fontWeight: FontWeight.w700)),
          ),
          child: Column(
            children: [
              if (isMobile) ...[
                _buildInputField(
                  isMobile: isMobile,
                  label: 'Full Name *',
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  isMobile: isMobile,
                  label: 'Employee ID',
                  controller: _employeeIdController,
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  isMobile: isMobile,
                  label: 'Email Address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  isMobile: isMobile,
                  label: 'Mobile Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => setState(() {}),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        isMobile: isMobile,
                        label: 'Full Name *',
                        controller: _nameController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildInputField(
                        isMobile: isMobile,
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
                        isMobile: isMobile,
                        label: 'Email Address',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildInputField(
                        isMobile: isMobile,
                        label: 'Mobile Number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // 2. Work Information Card
        _buildSectionCard(
          isMobile: isMobile,
          icon: Icons.group_outlined,
          title: 'Work Information',
          child: Column(
            children: [
              if (isMobile) ...[
                _buildDropdownField(
                  isMobile: isMobile,
                  label: 'Role *',
                  value: _selectedRole,
                  items: _roleOptions,
                  onAddPressed: _showAddRoleDialog,
                  addLabel: 'Add Role',
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRole = val);
                      _applyRolePreset(val);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdownField(
                  isMobile: isMobile,
                  label: 'Department',
                  value: _selectedDepartment,
                  items: _departmentOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDepartment = val);
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdownField(
                  isMobile: isMobile,
                  label: 'Business Branch *',
                  value: _selectedLocation,
                  items: _locationOptions,
                  onAddPressed: _showAddBranchDialog,
                  addLabel: 'Add Branch',
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLocation = val);
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdownField(
                  isMobile: isMobile,
                  label: 'Reporting To',
                  value: _selectedReportingTo,
                  items: _reportingToOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedReportingTo = val);
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        isMobile: isMobile,
                        label: 'Role *',
                        value: _selectedRole,
                        items: _roleOptions,
                        onAddPressed: _showAddRoleDialog,
                        addLabel: 'Add Role',
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
                        isMobile: isMobile,
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
                        isMobile: isMobile,
                        label: 'Business Branch *',
                        value: _selectedLocation,
                        items: _locationOptions,
                        onAddPressed: _showAddBranchDialog,
                        addLabel: 'Add Branch',
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLocation = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildDropdownField(
                        isMobile: isMobile,
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
            ],
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // 3. Preferences Card
        _buildSectionCard(
          isMobile: isMobile,
          icon: Icons.shield_outlined,
          title: 'Preferences',
          child: isMobile
              ? Column(
                  children: [
                    _buildDropdownField(
                      isMobile: isMobile,
                      label: 'Language',
                      value: _selectedLanguage,
                      items: _languageOptions,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLanguage = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      isMobile: isMobile,
                      label: 'Theme',
                      value: _selectedTheme,
                      items: _themeOptions,
                      prefixIcon: Icons.wb_sunny_outlined,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTheme = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      isMobile: isMobile,
                      label: 'Default Screen',
                      value: _selectedDefaultScreen,
                      items: _defaultScreenOptions,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDefaultScreen = val);
                      },
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        isMobile: isMobile,
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
                        isMobile: isMobile,
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
                        isMobile: isMobile,
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
        SizedBox(height: isMobile ? 12 : 16),

        // 4. Login & Security Card
        _buildSectionCard(
          isMobile: isMobile,
          icon: Icons.shield_outlined,
          title: 'Login & Security',
          child: isMobile
              ? Column(
                  children: [
                    // Change PIN Container
                    Container(
                      padding: const EdgeInsets.all(10),
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
                            child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Change PIN',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Update login PIN',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _showChangePinDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Change PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Biometric Login Container
                    Container(
                      padding: const EdgeInsets.all(10),
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
                            child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF2563EB), size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biometric Login',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Fingerprint access',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: _enableBiometric,
                              activeThumbColor: const Color(0xFF2563EB),
                              activeTrackColor: const Color(0xFF93C5FD),
                              inactiveThumbColor: const Color(0xFF94A3B8),
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                              onChanged: (val) => setState(() => _enableBiometric = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
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
                              activeThumbColor: const Color(0xFF2563EB),
                              activeTrackColor: const Color(0xFF93C5FD),
                              inactiveThumbColor: const Color(0xFF94A3B8),
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                              onChanged: (val) => setState(() => _enableBiometric = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        // 5. Account Status Card
        _buildSectionCard(
          isMobile: isMobile,
          icon: Icons.info_outline_rounded,
          title: 'Account Status',
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _isActive,
                            activeThumbColor: const Color(0xFF2563EB),
                            activeTrackColor: const Color(0xFF93C5FD),
                            inactiveThumbColor: const Color(0xFF94A3B8),
                            inactiveTrackColor: const Color(0xFFE2E8F0),
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isActive ? 'Active' : 'Inactive',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const Text(
                                'Staff member can access the system',
                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    const Text('Last Login', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(_currentStaff.updatedAt ?? DateTime.now()),
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  const Flexible(
                                    child: Text(
                                      'From Windows • Store Device',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
                )
              : Row(
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
                                activeThumbColor: const Color(0xFF2563EB),
                                activeTrackColor: const Color(0xFF93C5FD),
                                inactiveThumbColor: const Color(0xFF94A3B8),
                                inactiveTrackColor: const Color(0xFFE2E8F0),
                                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
                                            'From Windows • Store Device',
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
        SizedBox(height: isMobile ? 12 : 16),

        // 6. Delete Staff Card
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
            border: Border.all(color: const Color(0xFFFECACA), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded, color: const Color(0xFFEF4444), size: isMobile ? 17 : 22),
              ),
              SizedBox(width: isMobile ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Staff',
                      style: TextStyle(
                        fontSize: isMobile ? 12.5 : 14.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Permanently remove this staff member',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12.5,
                        color: const Color(0xFF7F1D1D),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 18,
                    vertical: isMobile ? 6 : 10,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Delete', style: TextStyle(fontSize: isMobile ? 11.5 : 13, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 1: DYNAMIC PERMISSIONS ====================
  Widget _buildPermissionsTab(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role Preset Quick Selector Card
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dynamic Permissions Matrix',
                          style: TextStyle(
                            fontSize: isMobile ? 13.5 : 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Customize granular access or apply role template presets',
                          style: TextStyle(fontSize: isMobile ? 10.5 : 12.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Role Presets:',
                    style: TextStyle(fontSize: isMobile ? 11 : 13, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                  ),
                  ...['Admin', 'Manager', 'Cashier', 'Waiter', 'Chef'].map((r) {
                    final isCurrent = _selectedRole.toLowerCase() == r.toLowerCase();
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8, vertical: isMobile ? 2 : 4),
                      label: Text(r, style: TextStyle(fontSize: isMobile ? 10.5 : 12, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600)),
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
        SizedBox(height: isMobile ? 12 : 16),

        // Permission Categories List
        ..._permissionCategories.map((catData) {
          final label = catData['label'] as String;
          final icon = catData['icon'] as IconData;
          final items = catData['items'] as List<Map<String, String>>;

          final selectedCount = items.where((i) => _selectedPermissions.contains(i['id'])).length;
          final allCategorySelected = selectedCount == items.length && items.isNotEmpty;

          return Container(
            margin: EdgeInsets.only(bottom: isMobile ? 10 : 16),
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
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
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: const Color(0xFF2563EB), size: isMobile ? 16 : 19),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 15.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: selectedCount > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: selectedCount > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '$selectedCount / ${items.length}',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11.5,
                              fontWeight: FontWeight.w700,
                              color: selectedCount > 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
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
                        style: TextStyle(fontSize: isMobile ? 11 : 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
                Divider(color: const Color(0xFFF1F5F9), height: isMobile ? 14 : 20),

                // Granular Permission Items
                ...items.map((item) {
                  final pId = item['id']!;
                  final isChecked = _selectedPermissions.contains(pId);

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 3 : 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']!,
                                style: TextStyle(
                                  fontSize: isMobile ? 11.5 : 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item['subtitle']!,
                                style: TextStyle(fontSize: isMobile ? 9.5 : 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: isMobile ? 0.8 : 1.0,
                          child: Switch(
                            value: isChecked,
                            activeThumbColor: const Color(0xFF2563EB),
                            activeTrackColor: const Color(0xFF93C5FD),
                            inactiveThumbColor: const Color(0xFF94A3B8),
                            inactiveTrackColor: const Color(0xFFE2E8F0),
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
  Widget _buildWorkSettingsTab(bool isMobile) {
    return Column(
      children: [
        _buildSectionCard(
          isMobile: isMobile,
          icon: Icons.work_history_outlined,
          title: 'Shift & Compensation',
          child: Column(
            children: [
              if (isMobile) ...[
                _buildDropdownField(
                  isMobile: isMobile,
                  label: 'Assigned Shift',
                  value: _selectedShift,
                  items: _shiftOptions,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedShift = v);
                  },
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  isMobile: isMobile,
                  label: 'Monthly Salary / Pay (₹)',
                  controller: _salaryController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Joining Date', style: TextStyle(fontSize: isMobile ? 11 : 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                    const SizedBox(height: 4),
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: isMobile ? 36 : 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _joiningDate != null
                                  ? DateFormat('dd MMM yyyy').format(_joiningDate!)
                                  : 'Select date',
                              style: TextStyle(fontSize: isMobile ? 11.5 : 13.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                            ),
                            Icon(Icons.calendar_today_outlined, size: isMobile ? 14 : 16, color: const Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  isMobile: isMobile,
                  label: 'Notes & Internal Comments',
                  controller: _notesController,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        isMobile: isMobile,
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
                        isMobile: isMobile,
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
                  isMobile: isMobile,
                  label: 'Notes & Internal Comments',
                  controller: _notesController,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 3: SECURITY ====================
  Widget _buildSecurityTab(bool isMobile) {
    return Column(
      children: [
        _buildSectionCard(
          isMobile: isMobile,
          icon: Icons.security_rounded,
          title: 'Security & Access Control',
          child: Column(
            children: [
              if (isMobile) ...[
                _buildInputField(
                  isMobile: isMobile,
                  label: 'POS Login PIN (4 Digits)',
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showChangePinDialog,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      foregroundColor: const Color(0xFF2563EB),
                    ),
                    icon: const Icon(Icons.pin_rounded, size: 15),
                    label: const Text('Reset PIN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        isMobile: isMobile,
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
              ],
              SizedBox(height: isMobile ? 10 : 16),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 4),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
                  title: Text(
                    'Force Password Change on Next Login',
                    style: TextStyle(
                      fontSize: isMobile ? 11.5 : 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Requires user to set a new password when signing in',
                    style: TextStyle(fontSize: isMobile ? 9.5 : 11.5, color: const Color(0xFF64748B)),
                  ),
                  value: _forcePasswordChange,
                  activeThumbColor: const Color(0xFF2563EB),
                  activeTrackColor: const Color(0xFF93C5FD),
                  inactiveThumbColor: const Color(0xFF94A3B8),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  onChanged: (v) => setState(() => _forcePasswordChange = v),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
                  title: Text(
                    'Send Welcome Email with Credentials',
                    style: TextStyle(
                      fontSize: isMobile ? 11.5 : 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Dispatches onboarding instructions and login link',
                    style: TextStyle(fontSize: isMobile ? 9.5 : 11.5, color: const Color(0xFF64748B)),
                  ),
                  value: _sendWelcomeEmail,
                  activeThumbColor: const Color(0xFF2563EB),
                  activeTrackColor: const Color(0xFF93C5FD),
                  inactiveThumbColor: const Color(0xFF94A3B8),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
  Widget _buildActivityTab(bool isMobile) {
    final activities = [
      {'title': 'Logged into Windows POS Counter', 'time': 'Today, 10:42 AM', 'icon': Icons.login_rounded, 'color': const Color(0xFF16A34A)},
      {'title': 'Completed Order #20260922-004 (₹420)', 'time': 'Today, 10:15 AM', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF2563EB)},
      {'title': 'Printed KOT for Table T-02', 'time': 'Today, 09:50 AM', 'icon': Icons.print_rounded, 'color': const Color(0xFF7C3AED)},
      {'title': 'Applied ₹50 Promo Discount on Bill', 'time': 'Yesterday, 08:30 PM', 'icon': Icons.local_offer_outlined, 'color': const Color(0xFFEA580C)},
      {'title': 'Shift Opened: Morning Shift (8 AM - 4 PM)', 'time': 'Yesterday, 08:00 AM', 'icon': Icons.schedule_rounded, 'color': const Color(0xFF0284C7)},
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Staff Activity & Audit Trail', style: TextStyle(fontSize: isMobile ? 13.5 : 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text('Recent actions and POS events executed by this staff member', style: TextStyle(fontSize: isMobile ? 10.5 : 12.5, color: const Color(0xFF64748B))),
          SizedBox(height: isMobile ? 10 : 16),
          ...activities.map((a) => Padding(
                padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 6 : 9),
                      decoration: BoxDecoration(
                        color: (a['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: isMobile ? 14 : 18),
                    ),
                    SizedBox(width: isMobile ? 8 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['title'] as String, style: TextStyle(fontSize: isMobile ? 11.5 : 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                          const SizedBox(height: 1),
                          Text(a['time'] as String, style: TextStyle(fontSize: isMobile ? 9.5 : 11.5, color: const Color(0xFF94A3B8))),
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
    required bool isMobile,
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
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
                  Icon(icon, size: isMobile ? 16 : 20, color: const Color(0xFF334155)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 13.5 : 15.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: isMobile ? 10 : 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required bool isMobile,
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
          style: TextStyle(
            fontSize: isMobile ? 11 : 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13.5,
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: isMobile ? 8 : 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required bool isMobile,
    required String label,
    required String value,
    required List<String> items,
    IconData? prefixIcon,
    VoidCallback? onAddPressed,
    String? addLabel,
    required void Function(String?) onChanged,
  }) {
    final cleanValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            if (onAddPressed != null)
              InkWell(
                onTap: onAddPressed,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: isMobile ? 12 : 14, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 2),
                      Text(
                        addLabel ?? 'Add',
                        style: TextStyle(
                          fontSize: isMobile ? 10.5 : 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: cleanValue,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFF64748B), size: isMobile ? 16 : 18),
          style: TextStyle(fontSize: isMobile ? 12 : 13.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: isMobile ? 16 : 18, color: const Color(0xFF64748B)) : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: isMobile ? 8 : 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
          items: items
              .map((it) => DropdownMenuItem(
                    value: it,
                    child: Text(it, style: TextStyle(fontSize: isMobile ? 12 : 13.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}