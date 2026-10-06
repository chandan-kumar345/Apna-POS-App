import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/services/staff_service.dart';
import '../../../core/services/upload_service.dart';

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
  String _selectedLocation = 'Main Branch';
  String _selectedShift = 'Morning Shift (8 AM - 4 PM)';

  // Security State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _forcePasswordChange = false;

  // Permissions State
  String _selectedPermissionCategory = 'pos';
  final Set<String> _selectedPermissions = {
    'pos_access',
    'pos_create_order',
    'pos_apply_discount',
    'pos_print_receipt',
    'pos_takeaway_delivery',
    'tables_view',
    'orders_view',
    'orders_status_update',
    'menu_view',
    'menu_availability',
    'crm_view',
    'crm_add_edit',
    'reports_view_own',
  };

  // Preferences State
  String _selectedLanguage = 'English';
  String _selectedTheme = 'Light';
  String _selectedDefaultScreen = 'POS Billing';
  bool _enableBiometric = false;

  // Account Status & Options
  bool _isActive = true;
  bool _sendWelcomeEmail = true;
  bool _isSubmitting = false;

  File? _avatarImageFile;
  final ImagePicker _picker = ImagePicker();

  // Lists of Options
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

  // 12 Navigation Sidebar Categories for Permissions
  final List<Map<String, dynamic>> _permissionCategories = [
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.home_rounded},
    {'id': 'pos', 'label': 'POS Billing', 'icon': Icons.point_of_sale_rounded},
    {'id': 'tables', 'label': 'Tables & Floor', 'icon': Icons.table_restaurant_rounded},
    {'id': 'orders', 'label': 'My Orders & KDS', 'icon': Icons.receipt_long_rounded},
    {'id': 'menu', 'label': 'Menu & Catalog', 'icon': Icons.dinner_dining_rounded},
    {'id': 'inventory', 'label': 'Inventory', 'icon': Icons.inventory_2_rounded},
    {'id': 'reports', 'label': 'Sales Report', 'icon': Icons.bar_chart_rounded},
    {'id': 'crm', 'label': 'CRM Customers', 'icon': Icons.people_alt_rounded},
    {'id': 'loyalty', 'label': 'Loyalty Program', 'icon': Icons.card_giftcard_rounded},
    {'id': 'campaign', 'label': 'Campaigns', 'icon': Icons.campaign_rounded},
    {'id': 'staff', 'label': 'Staff Setting', 'icon': Icons.badge_rounded},
    {'id': 'settings', 'label': 'Business Setting', 'icon': Icons.settings_rounded},
  ];

  // Map of permissions by category with detailed sub-options
  final Map<String, List<Map<String, String>>> _permissionsByCategory = {
    'dashboard': [
      {'id': 'dashboard_view', 'title': 'View Dashboard & Summary', 'subtitle': 'View sales metrics, total revenues & statistics'},
      {'id': 'dashboard_realtime', 'title': 'Real-time Sales Tracking', 'subtitle': 'Track live orders counter and revenue stream'},
      {'id': 'dashboard_quick_actions', 'title': 'Access Quick Actions', 'subtitle': 'Use dashboard shortcut buttons and fast actions'},
      {'id': 'dashboard_recent_activity', 'title': 'Live Activity Stream', 'subtitle': 'View recent customer orders and floor updates'},
    ],
    'pos': [
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
    'tables': [
      {'id': 'tables_view', 'title': 'View Dining Tables', 'subtitle': 'View live floor tables status and occupancy'},
      {'id': 'tables_manage', 'title': 'Manage Tables & Floor', 'subtitle': 'Create, edit, rename and arrange dining tables'},
      {'id': 'tables_transfer', 'title': 'Transfer & Merge Tables', 'subtitle': 'Shift running orders between tables and merge'},
      {'id': 'tables_reservation', 'title': 'Manage Reservations', 'subtitle': 'Reserve and schedule tables for upcoming guests'},
    ],
    'orders': [
      {'id': 'orders_view', 'title': 'View Orders Directory', 'subtitle': 'Browse all live, pending and completed orders'},
      {'id': 'orders_edit', 'title': 'Edit Running Orders', 'subtitle': 'Add more items and update kitchen instructions'},
      {'id': 'orders_status_update', 'title': 'Update Order Status', 'subtitle': 'Mark orders as Preparing, Ready, Served, Done'},
      {'id': 'orders_kds', 'title': 'Kitchen Display (KDS)', 'subtitle': 'Access digital kitchen order display system'},
      {'id': 'orders_kot', 'title': 'Print & Re-print KOT', 'subtitle': 'Send and re-print Kitchen Order Tickets'},
    ],
    'menu': [
      {'id': 'menu_view', 'title': 'View Menu Catalog', 'subtitle': 'Browse food catalog, prices and categories'},
      {'id': 'menu_add', 'title': 'Add New Dishes', 'subtitle': 'Create new menu items with images and prices'},
      {'id': 'menu_edit', 'title': 'Edit Menu & Pricing', 'subtitle': 'Update prices, descriptions and modifiers'},
      {'id': 'menu_delete', 'title': 'Delete / Archive Items', 'subtitle': 'Remove dishes from catalog or archive'},
      {'id': 'menu_categories', 'title': 'Manage Categories', 'subtitle': 'Create, reorder and organize categories'},
      {'id': 'menu_availability', 'title': 'Item Availability (86)', 'subtitle': 'Toggle items in-stock or out of stock instantly'},
    ],
    'inventory': [
      {'id': 'inventory_view', 'title': 'View Raw Stock Levels', 'subtitle': 'Monitor ingredients quantity and stock values'},
      {'id': 'inventory_adjust', 'title': 'Stock In / Stock Out', 'subtitle': 'Log manual stock additions and inward batches'},
      {'id': 'inventory_wastage', 'title': 'Log Stock Wastage', 'subtitle': 'Record damaged, expired or wasted inventory'},
      {'id': 'inventory_alerts', 'title': 'Low Stock Alerts', 'subtitle': 'Receive low inventory and threshold warnings'},
      {'id': 'inventory_purchases', 'title': 'Purchase Orders & Vendors', 'subtitle': 'Manage supplier invoices and purchase orders'},
    ],
    'reports': [
      {'id': 'reports_view_own', 'title': 'View Own Sales Summary', 'subtitle': 'Track own shift cash collections and bills'},
      {'id': 'reports_daily_sales', 'title': 'Daily Sales Report', 'subtitle': 'View total store day-end sales summary'},
      {'id': 'reports_financial', 'title': 'Financials & Tax Breakdown', 'subtitle': 'Access profit/loss, GST tax reports and margins'},
      {'id': 'reports_item_sales', 'title': 'Item-wise Sales Analytics', 'subtitle': 'Analyze bestsellers and category sales performance'},
      {'id': 'reports_export', 'title': 'Export Data (Excel & PDF)', 'subtitle': 'Download sales reports in Excel and PDF formats'},
      {'id': 'reports_staff_performance', 'title': 'Staff Sales Performance', 'subtitle': 'Track sales generated per cashier / staff member'},
    ],
    'crm': [
      {'id': 'crm_view', 'title': 'View Customer Directory', 'subtitle': 'Access customer accounts and order histories'},
      {'id': 'crm_add_edit', 'title': 'Add & Edit Customers', 'subtitle': 'Register customer details, phones and addresses'},
      {'id': 'crm_delete', 'title': 'Delete Customer Records', 'subtitle': 'Remove duplicate or obsolete customer records'},
      {'id': 'crm_khata', 'title': 'Customer Khata / Credit Ledger', 'subtitle': 'Manage customer credit balances and payments'},
      {'id': 'crm_tags', 'title': 'Customer Tags & Segments', 'subtitle': 'Tag VIP and regular customers for promotions'},
    ],
    'loyalty': [
      {'id': 'loyalty_view', 'title': 'View Loyalty Members', 'subtitle': 'Check customer loyalty points and tier status'},
      {'id': 'loyalty_reward', 'title': 'Issue Points & Stamps', 'subtitle': 'Award loyalty points on purchases and stamp cards'},
      {'id': 'loyalty_redeem', 'title': 'Redeem Loyalty Points', 'subtitle': 'Apply loyalty points for bill discounts'},
      {'id': 'loyalty_manage_tiers', 'title': 'Configure Loyalty Rules', 'subtitle': 'Set point conversion rates and tier thresholds'},
    ],
    'campaign': [
      {'id': 'campaign_view', 'title': 'View Marketing Campaigns', 'subtitle': 'Track promotional campaign performance & ROI'},
      {'id': 'campaign_create', 'title': 'Create SMS / WhatsApp Blasts', 'subtitle': 'Draft and launch marketing messages'},
      {'id': 'campaign_templates', 'title': 'Manage Message Templates', 'subtitle': 'Customize festival offers and discount coupons'},
      {'id': 'campaign_broadcast', 'title': 'Instant Flash Broadcast', 'subtitle': 'Send real-time alerts to customer segments'},
    ],
    'staff': [
      {'id': 'staff_view', 'title': 'View Staff Directory', 'subtitle': 'Browse team members, roles, and active status'},
      {'id': 'staff_add', 'title': 'Create New Staff', 'subtitle': 'Add employee accounts with login credentials'},
      {'id': 'staff_edit', 'title': 'Edit Staff & Permissions', 'subtitle': 'Update employee roles, PINs, and access rights'},
      {'id': 'staff_delete', 'title': 'Deactivate / Remove Staff', 'subtitle': 'Disable or delete staff accounts'},
      {'id': 'staff_shifts', 'title': 'Manage Shifts & Duty', 'subtitle': 'Assign work schedules and shift timings'},
    ],
    'settings': [
      {'id': 'settings_profile', 'title': 'Store & Business Profile', 'subtitle': 'Edit store name, logo, contact, and address'},
      {'id': 'settings_branches', 'title': 'Business Branches', 'subtitle': 'Manage multi-branch outlets and counters'},
      {'id': 'settings_printers', 'title': 'Printers & Hardware', 'subtitle': 'Configure Bluetooth, USB, Thermal, and KOT printers'},
      {'id': 'settings_taxes', 'title': 'Taxes & Service Charges', 'subtitle': 'Configure GST, VAT, service charges and packaging'},
      {'id': 'settings_payments', 'title': 'Payment Gateways & UPI QR', 'subtitle': 'Configure Razorpay, UPI QR, and payment terminals'},
      {'id': 'settings_receipt_template', 'title': 'Receipt Customization', 'subtitle': 'Customize bill headers, footers, and logo'},
      {'id': 'settings_chotu_ai', 'title': 'Chotu AI Voice Assistant', 'subtitle': 'Configure smart voice order taking and prompts'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _initDynamicOptions();
    _autoGenerateEmployeeId();
    _applyRolePreset(_selectedRole);
  }

  void _initDynamicOptions() {
    // 1. Dynamic Roles
    _roleOptions = _db.allStaffRoles;
    if (!_roleOptions.contains(_selectedRole)) {
      _selectedRole = _roleOptions.isNotEmpty ? _roleOptions.first : 'Cashier';
    }

    // 2. Dynamic Reporting To (Store Owner + Previous Staff)
    final ownerName = _db.restaurant?.name.trim().isNotEmpty == true
        ? _db.restaurant!.name.trim()
        : (_db.currentUser?.name.trim().isNotEmpty == true ? _db.currentUser!.name.trim() : 'Store Owner');
    final ownerOption = 'Store Owner / Admin ($ownerName)';

    final List<String> reportingList = [ownerOption];
    for (final s in _db.staffList) {
      final staffOption = '${s.name} (${s.role} • ${s.employeeId.isNotEmpty ? s.employeeId : 'Staff'})';
      if (!reportingList.contains(staffOption)) {
        reportingList.add(staffOption);
      }
    }
    if (!reportingList.contains('None')) {
      reportingList.add('None');
    }
    _reportingToOptions = reportingList;
    _selectedReportingTo = reportingList.first;

    // 3. Dynamic Business Branches
    _locationOptions = _db.allBusinessBranches;
    if (_locationOptions.isNotEmpty && !_locationOptions.contains(_selectedLocation)) {
      _selectedLocation = _locationOptions.first;
    }
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
            Text(
              'Add Custom Role',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the title for the new staff role (e.g. Floor Supervisor, Bartender, Delivery Coordinator).',
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
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
                    _roleOptions = _db.allStaffRoles;
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
            Text(
              'Add Business Branch',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
            ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
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
                    _locationOptions = _db.allBusinessBranches;
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

  void _applyRolePreset(String role) {
    final perms = <String>{};
    String defaultScr = _selectedDefaultScreen;
    switch (role.toLowerCase()) {
      case 'admin':
        for (final catList in _permissionsByCategory.values) {
          for (final item in catList) {
            perms.add(item['id']!);
          }
        }
        defaultScr = 'Dashboard';
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
        defaultScr = 'Dashboard';
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
        defaultScr = 'POS Billing';
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
        defaultScr = 'Tables / Floor';
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
        defaultScr = 'Orders List';
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
        defaultScr = 'Dashboard';
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
        defaultScr = 'POS Billing';
        break;
      case 'support':
        perms.addAll([
          'crm_view',
          'crm_add_edit',
          'crm_khata',
          'orders_view',
          'reports_view_own',
        ]);
        defaultScr = 'Orders List';
        break;
      default:
        perms.addAll([
          'pos_access',
          'pos_create_order',
          'pos_apply_discount',
          'pos_print_receipt',
          'menu_view',
        ]);
        defaultScr = 'POS Billing';
    }
    setState(() {
      _selectedPermissions.clear();
      _selectedPermissions.addAll(perms);
      _selectedDefaultScreen = defaultScr;
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
      final employeeId = _employeeIdController.text.trim().isNotEmpty
          ? _employeeIdController.text.trim()
          : 'EMP${(_db.staffList.length + 1).toString().padLeft(3, '0')}';

      // Pin derivation
      String pin = '1234';
      if (password.length >= 4 && password.length <= 6 && RegExp(r'^\d+$').hasMatch(password)) {
        pin = password;
      } else if (phone.replaceAll(RegExp(r'\D'), '').length >= 4) {
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        pin = digits.substring(digits.length - 4);
      }

      // Cloudflare R2 Upload for Staff Profile Picture
      String remoteAvatarUrl = '';
      if (_avatarImageFile != null) {
        try {
          final uploaded = await UploadService().uploadImage(_avatarImageFile!, folder: 'profiles');
          if (uploaded != null && uploaded.isNotEmpty) {
            remoteAvatarUrl = uploaded;
            debugPrint('[CreateStaffScreen] Staff avatar uploaded to Cloudflare R2: $remoteAvatarUrl');
          }
        } catch (uploadErr) {
          debugPrint('[CreateStaffScreen] Cloudflare R2 upload error: $uploadErr');
        }
        if (remoteAvatarUrl.isEmpty) {
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

      final newStaff = StaffModel(
        id: 'st_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        employeeId: employeeId,
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
        avatarUrl: remoteAvatarUrl,
        pin: pin,
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
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF2563EB);
            }
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Header Bar
                      _buildTopHeader(isMobile),
                      SizedBox(height: isMobile ? 12 : 20),

                      // Responsive 2-Column or Stacked Layout
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
                                      _buildBasicInfoCard(isMobile),
                                      const SizedBox(height: 16),
                                      _buildWorkDetailsCard(isMobile),
                                      const SizedBox(height: 16),
                                      _buildLoginSecurityCard(isMobile),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Right Column (50%)
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      _buildPermissionsCard(isMobile),
                                      const SizedBox(height: 16),
                                      _buildPreferencesCard(isMobile),
                                      const SizedBox(height: 16),
                                      _buildAccountStatusCard(isMobile),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          // Stacked layout for smaller window & mobile sizes
                          return Column(
                            children: [
                              _buildBasicInfoCard(isMobile),
                              SizedBox(height: isMobile ? 10 : 16),
                              _buildWorkDetailsCard(isMobile),
                              SizedBox(height: isMobile ? 10 : 16),
                              _buildLoginSecurityCard(isMobile),
                              SizedBox(height: isMobile ? 10 : 16),
                              _buildPermissionsCard(isMobile),
                              SizedBox(height: isMobile ? 10 : 16),
                              _buildPreferencesCard(isMobile),
                              SizedBox(height: isMobile ? 10 : 16),
                              _buildAccountStatusCard(isMobile),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: isMobile ? 14 : 20),

                      // Bottom Action Bar
                      _buildBottomActionBar(isMobile),
                      SizedBox(height: isMobile ? 16 : 24),
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

  // --- Top Header Bar ---
  Widget _buildTopHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Staff',
                style: TextStyle(
                  fontSize: isMobile ? 16.5 : 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Add a new team member to your business',
                style: TextStyle(
                  fontSize: isMobile ? 10.5 : 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // "View Staff List" Header Button
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 16,
              vertical: isMobile ? 7 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(Icons.people_alt_outlined, size: isMobile ? 15 : 18),
          label: Text(
            'View Staff List',
            style: TextStyle(
              fontSize: isMobile ? 11 : 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== BASIC INFO CARD ====================
  Widget _buildBasicInfoCard(bool isMobile) {
    return _buildCardWrapper(
      isMobile: isMobile,
      icon: Icons.person_outline_rounded,
      title: 'Basic Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            // Avatar Center/Top on Mobile
            Center(
              child: _buildAvatarSection(isMobile),
            ),
            const SizedBox(height: 12),
            _buildFieldLabel('Full Name *', isMobile),
            const SizedBox(height: 4),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                isMobile: isMobile,
                hint: 'Enter full name',
                icon: Icons.person_outline_rounded,
              ),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
            ),
            const SizedBox(height: 10),
            _buildFieldLabel('Employee ID *', isMobile),
            const SizedBox(height: 4),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                TextFormField(
                  controller: _employeeIdController,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: _inputDecoration(
                    isMobile: isMobile,
                    hint: 'EMP00X',
                    icon: Icons.badge_outlined,
                  ).copyWith(
                    contentPadding: const EdgeInsets.only(
                      left: 10,
                      right: 80,
                      top: 8,
                      bottom: 8,
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel('Role *', isMobile),
                InkWell(
                  onTap: _showAddRoleDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 2),
                        Text(
                          'Add Role',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedRole,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                isMobile: isMobile,
                hint: 'Select role',
                icon: Icons.work_outline_rounded,
              ),
              items: _roleOptions
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRole = val);
                  _applyRolePreset(val);
                }
              },
            ),
            const SizedBox(height: 10),
            _buildFieldLabel('Email Address *', isMobile),
            const SizedBox(height: 4),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                isMobile: isMobile,
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
            const SizedBox(height: 10),
            _buildFieldLabel('Mobile Number', isMobile),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 76,
                  margin: const EdgeInsets.only(right: 6),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCountryCode,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 14),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    decoration: _inputDecoration(isMobile: isMobile, hint: '+91', icon: Icons.phone_outlined)
                        .copyWith(
                      prefixIcon: null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    ),
                    items: _countryCodes
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCountryCode = val);
                    },
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: _inputDecoration(
                      isMobile: isMobile,
                      hint: '98765 43210',
                      icon: Icons.phone_android_rounded,
                    ).copyWith(prefixIcon: null),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Desktop 2-column Basic Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarSection(isMobile),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Full Name *', isMobile),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(
                          isMobile: isMobile,
                          hint: 'Enter full name',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Employee ID *', isMobile),
                                const SizedBox(height: 6),
                                Stack(
                                  alignment: Alignment.centerRight,
                                  children: [
                                    TextFormField(
                                      controller: _employeeIdController,
                                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                      decoration: _inputDecoration(
                                        isMobile: isMobile,
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
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(child: _buildFieldLabel('Role *', isMobile)),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: _showAddRoleDialog,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_rounded, size: 13, color: Color(0xFF2563EB)),
                                            SizedBox(width: 2),
                                            Text(
                                              'Add Role',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _selectedRole,
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                  decoration: _inputDecoration(
                                    isMobile: isMobile,
                                    hint: 'Select role',
                                    icon: Icons.work_outline_rounded,
                                  ),
                                  items: _roleOptions
                                      .map((r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(r, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedRole = val);
                                      _applyRolePreset(val);
                                    }
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Email Address *', isMobile),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(
                          isMobile: isMobile,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Mobile Number', isMobile),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 88,
                            margin: const EdgeInsets.only(right: 6),
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedCountryCode,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              decoration: _inputDecoration(isMobile: isMobile, hint: '+91', icon: Icons.phone_outlined)
                                   .copyWith(
                                prefixIcon: null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                              ),
                              items: _countryCodes
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCountryCode = val);
                              },
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                              decoration: _inputDecoration(
                                isMobile: isMobile,
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
        ],
      ),
    );
  }

  Widget _buildAvatarSection(bool isMobile) {
    final size = isMobile ? 56.0 : 82.0;
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatarImage,
          child: Stack(
            children: [
              Container(
                width: size,
                height: size,
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
                    ? Icon(Icons.person_rounded, size: isMobile ? 30 : 44, color: const Color(0xFF94A3B8))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 3.5 : 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(Icons.camera_alt_rounded, size: isMobile ? 10 : 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload Photo',
          style: TextStyle(fontSize: isMobile ? 10.5 : 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
        ),
        Text(
          'JPG, PNG (Max 2MB)',
          style: TextStyle(fontSize: isMobile ? 9 : 10.5, color: const Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  // ==================== WORK DETAILS CARD ====================
  Widget _buildWorkDetailsCard(bool isMobile) {
    return _buildCardWrapper(
      isMobile: isMobile,
      icon: Icons.business_center_outlined,
      title: 'Work Details',
      child: Column(
        children: [
          if (isMobile) ...[
            _buildFieldLabel('Department', isMobile),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedDepartment,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isMobile: isMobile, hint: 'Select department', icon: Icons.domain_rounded),
              items: _departmentOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDepartment = val);
              },
            ),
            const SizedBox(height: 10),
            _buildFieldLabel('Reporting To', isMobile),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedReportingTo,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isMobile: isMobile, hint: 'Select manager', icon: Icons.supervisor_account_outlined),
              items: _reportingToOptions
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReportingTo = val);
              },
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: _buildFieldLabel('Business Branch *', isMobile)),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _showAddBranchDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 2),
                        Text(
                          'Add Branch',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedLocation,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isMobile: isMobile, hint: 'Select branch', icon: Icons.location_on_outlined),
              items: _locationOptions
                  .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLocation = val);
              },
            ),
            const SizedBox(height: 10),
            _buildFieldLabel('Shift / Working Hours', isMobile),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedShift,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isMobile: isMobile, hint: 'Select shift', icon: Icons.schedule_outlined),
              items: _shiftOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedShift = val);
              },
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Department', isMobile),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedDepartment,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(isMobile: isMobile, hint: 'Select department', icon: Icons.domain_rounded),
                        items: _departmentOptions
                            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDepartment = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Reporting To', isMobile),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedReportingTo,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(isMobile: isMobile, hint: 'Select manager', icon: Icons.supervisor_account_outlined),
                        items: _reportingToOptions
                            .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: _buildFieldLabel('Business Branch *', isMobile)),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: _showAddBranchDialog,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 13, color: Color(0xFF2563EB)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Add Branch',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedLocation,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(isMobile: isMobile, hint: 'Select branch', icon: Icons.location_on_outlined),
                        items: _locationOptions
                            .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLocation = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Shift / Working Hours', isMobile),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedShift,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(isMobile: isMobile, hint: 'Select shift', icon: Icons.schedule_outlined),
                        items: _shiftOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
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
        ],
      ),
    );
  }

  // ==================== LOGIN & SECURITY CARD ====================
  Widget _buildLoginSecurityCard(bool isMobile) {
    return _buildCardWrapper(
      isMobile: isMobile,
      icon: Icons.lock_outline_rounded,
      title: 'Login & Security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            _buildFieldLabel('Set Password *', isMobile),
            const SizedBox(height: 4),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                isMobile: isMobile,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 16,
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
            const SizedBox(height: 10),
            _buildFieldLabel('Confirm Password *', isMobile),
            const SizedBox(height: 4),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                isMobile: isMobile,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 16,
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
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Set Password *', isMobile),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(
                          isMobile: isMobile,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Confirm Password *', isMobile),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(
                          isMobile: isMobile,
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
          ],
          SizedBox(height: isMobile ? 8 : 12),

          // Force Password Change Checkbox
          InkWell(
            onTap: () => setState(() => _forcePasswordChange = !_forcePasswordChange),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: isMobile ? 18 : 22,
                  height: isMobile ? 18 : 22,
                  child: Checkbox(
                    value: _forcePasswordChange,
                    activeColor: const Color(0xFF2563EB),
                    checkColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _forcePasswordChange = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Force password change on first login',
                  style: TextStyle(
                    fontSize: isMobile ? 11.5 : 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PERMISSIONS CARD ====================
  Widget _buildPermissionsCard(bool isMobile) {
    final activePermissions = _permissionsByCategory[_selectedPermissionCategory] ?? [];
    final int selectedCountInActive = activePermissions.where((p) => _selectedPermissions.contains(p['id'])).length;
    final bool allActiveSelected = activePermissions.isNotEmpty && selectedCountInActive == activePermissions.length;

    if (isMobile) {
      return _buildCardWrapper(
        isMobile: isMobile,
        icon: Icons.shield_outlined,
        title: 'Permissions Matrix',
        subtitle: 'Granular access for all 12 modules (${_selectedPermissions.length} granted)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Horizontal scrollable categories chip bar on Mobile
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _permissionCategories.map((cat) {
                  final catId = cat['id'] as String;
                  final isSelected = catId == _selectedPermissionCategory;
                  final catPerms = _permissionsByCategory[catId] ?? [];
                  final count = catPerms.where((p) => _selectedPermissions.contains(p['id'])).length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        cat['icon'] as IconData,
                        size: 14,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      backgroundColor: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onPressed: () => setState(() => _selectedPermissionCategory = catId),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Select All / Deselect All Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected $selectedCountInActive of ${activePermissions.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (allActiveSelected) {
                        for (final p in activePermissions) {
                          _selectedPermissions.remove(p['id']);
                        }
                      } else {
                        for (final p in activePermissions) {
                          _selectedPermissions.add(p['id']!);
                        }
                      }
                    });
                  },
                  child: Text(
                    allActiveSelected ? 'Deselect Category' : 'Select All in Category',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Checkbox Items Container
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: activePermissions.length,
                separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 10),
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
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: isChecked,
                              activeColor: const Color(0xFF2563EB),
                              checkColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  perm['title']!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isChecked ? FontWeight.w700 : FontWeight.w600,
                                    color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                  ),
                                ),
                                Text(
                                  perm['subtitle']!,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
    }

    return _buildCardWrapper(
      isMobile: isMobile,
      icon: Icons.shield_outlined,
      title: 'Permissions Matrix',
      subtitle: 'Dynamic permissions aligned with all 12 navigation modules (${_selectedPermissions.length} total granted)',
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Left Categories Sidebar (Tabs)
            Container(
              width: 175,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _permissionCategories.length,
                itemBuilder: (context, index) {
                  final cat = _permissionCategories[index];
                  final catId = cat['id'] as String;
                  final isSelected = catId == _selectedPermissionCategory;
                  final catPerms = _permissionsByCategory[catId] ?? [];
                  final count = catPerms.where((p) => _selectedPermissions.contains(p['id'])).length;

                  return InkWell(
                    onTap: () => setState(() => _selectedPermissionCategory = catId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (count > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
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
              child: Column(
                children: [
                  // Header inside Right Panel with Select All / Deselect All
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Category Access: $selectedCountInActive / ${activePermissions.length} enabled',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            setState(() {
                              if (allActiveSelected) {
                                for (final p in activePermissions) {
                                  _selectedPermissions.remove(p['id']);
                                }
                              } else {
                                for (final p in activePermissions) {
                                  _selectedPermissions.add(p['id']!);
                                }
                              }
                            });
                          },
                          child: Text(
                            allActiveSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Permission Checkboxes List
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
                                    checkColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
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
          ],
        ),
      ),
    );
  }

  // ==================== PREFERENCES CARD ====================
  Widget _buildPreferencesCard(bool isMobile) {
    return _buildCardWrapper(
      isMobile: isMobile,
      icon: Icons.tune_rounded,
      title: 'Preferences',
      child: Column(
        children: [
          if (isMobile) ...[
            _buildFieldLabel('Language', isMobile),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedLanguage,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isMobile: isMobile, hint: 'Language', icon: Icons.language_rounded),
              items: _languageOptions
                  .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLanguage = val);
              },
            ),
            const SizedBox(height: 10),
            _buildFieldLabel('Theme', isMobile),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedTheme,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isMobile: isMobile, hint: 'Theme', icon: Icons.wb_sunny_outlined),
              items: _themeOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedTheme = val);
              },
            ),
            const SizedBox(height: 10),
            _buildFieldLabel('Default Screen', isMobile),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedDefaultScreen,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isMobile: isMobile, hint: 'Default screen', icon: Icons.dashboard_outlined),
              items: _defaultScreenOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDefaultScreen = val);
              },
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Language', isMobile),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedLanguage,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(isMobile: isMobile, hint: 'Language', icon: Icons.language_rounded),
                        items: _languageOptions
                            .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLanguage = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Theme', isMobile),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedTheme,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(isMobile: isMobile, hint: 'Theme', icon: Icons.wb_sunny_outlined),
                        items: _themeOptions
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTheme = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Default Screen', isMobile),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedDefaultScreen,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: _inputDecoration(isMobile: isMobile, hint: 'Default screen', icon: Icons.dashboard_outlined),
                        items: _defaultScreenOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))))
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
          ],
          SizedBox(height: isMobile ? 8 : 12),

          // Enable Biometric Login Row
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 5 : 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fingerprint_rounded, color: const Color(0xFF2563EB), size: isMobile ? 16 : 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Biometric Login',
                        style: TextStyle(
                          fontSize: isMobile ? 11.5 : 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Use fingerprint for faster login',
                        style: TextStyle(fontSize: isMobile ? 9.5 : 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: isMobile ? 0.8 : 1.0,
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
      ),
    );
  }

  // ==================== ACCOUNT STATUS CARD ====================
  Widget _buildAccountStatusCard(bool isMobile) {
    if (isMobile) {
      return _buildCardWrapper(
        isMobile: isMobile,
        icon: Icons.power_settings_new_rounded,
        title: 'Account Status',
        child: Column(
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
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        _isActive ? 'Staff member can access the system' : 'Access disabled',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFFF1F5F9), height: 14),
            const Text('Last Login', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Not logged in yet',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'From Windows - Store Device',
                                style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
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
          ],
        ),
      );
    }

    return _buildCardWrapper(
      isMobile: isMobile,
      icon: Icons.power_settings_new_rounded,
      title: 'Account Status',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF64748B)),
                  SizedBox(width: 10),
                  Expanded(
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
                        Row(
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

  // ==================== BOTTOM ACTION BAR ====================
  Widget _buildBottomActionBar(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _sendWelcomeEmail = !_sendWelcomeEmail),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _sendWelcomeEmail,
                    activeColor: const Color(0xFF2563EB),
                    checkColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _sendWelcomeEmail = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Send welcome email with login details',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _handleCreateStaff,
                  icon: _isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.person_add_rounded, size: 16),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Create Staff',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                ),
              ),
            ],
          ),
        ],
      );
    }

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
                  checkColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
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
    required bool isMobile,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
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
                padding: EdgeInsets.all(isMobile ? 5 : 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: isMobile ? 15 : 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 13.5 : 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: isMobile ? 10 : 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 14),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isMobile) {
    final isRequired = label.contains('*');
    return Text(
      label,
      style: TextStyle(
        fontSize: isMobile ? 11 : 12.5,
        fontWeight: FontWeight.w700,
        color: isRequired ? const Color(0xFF1E293B) : const Color(0xFF475569),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required bool isMobile,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 11.5 : 12.5),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: isMobile ? 15 : 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 12,
        vertical: isMobile ? 8 : 10,
      ),
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
