import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/staff_model.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/features/staff/screens/staff_management_screen.dart';
import 'package:apna_pos/features/staff/screens/create_staff_screen.dart';
import 'package:apna_pos/features/staff/screens/staff_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StaffModel & StaffStatsModel Tests', () {
    test('StaffModel serialization, deserialization, and helper getters work correctly', () {
      final staff = StaffModel(
        id: 'st_001',
        name: 'Amit Sharma',
        employeeId: 'EMP001',
        phone: '9876543210',
        email: 'amit.sharma@apnapos.com',
        role: 'Admin',
        status: 'Active',
        department: 'Billing / Counter',
        workLocation: 'Main Store',
        reportingTo: 'Store Owner / Admin',
        password: 'Password@123',
        forcePasswordChange: true,
        permissions: const ['pos', 'tables', 'orders', 'menu'],
        salary: 25000,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(staff.isActive, isTrue);
      expect(staff.isAdmin, isTrue);
      expect(staff.isCashier, isFalse);
      expect(staff.initials, 'AS');
      expect(staff.department, 'Billing / Counter');
      expect(staff.workLocation, 'Main Store');
      expect(staff.reportingTo, 'Store Owner / Admin');
      expect(staff.forcePasswordChange, isTrue);
      expect(staff.roleTextColor, const Color(0xFF7C3AED));
      expect(staff.roleBgColor, const Color(0xFFEDE9FE));

      final json = staff.toJson();
      expect(json['name'], 'Amit Sharma');
      expect(json['employeeId'], 'EMP001');
      expect(json['role'], 'Admin');
      expect(json['status'], 'Active');
      expect(json['department'], 'Billing / Counter');
      expect(json['workLocation'], 'Main Store');
      expect(json['reportingTo'], 'Store Owner / Admin');
      expect(json['forcePasswordChange'], isTrue);
      expect(json['password'], 'Password@123');

      final fromJson = StaffModel.fromJson(json);
      expect(fromJson.name, 'Amit Sharma');
      expect(fromJson.employeeId, 'EMP001');
      expect(fromJson.role, 'Admin');
      expect(fromJson.status, 'Active');
      expect(fromJson.department, 'Billing / Counter');
      expect(fromJson.workLocation, 'Main Store');
      expect(fromJson.reportingTo, 'Store Owner / Admin');
      expect(fromJson.forcePasswordChange, isTrue);
    });

    test('StaffModel parses Inactive and other roles accurately', () {
      final staff = StaffModel(
        id: 'st_006',
        name: 'Karan Joshi',
        employeeId: 'EMP006',
        role: 'Support',
        status: 'Inactive',
        createdAt: DateTime.now(),
      );

      expect(staff.isActive, isFalse);
      expect(staff.isAdmin, isFalse);
      expect(staff.initials, 'KJ');
      expect(staff.roleTextColor, const Color(0xFF475569));
      expect(staff.roleBgColor, const Color(0xFFF1F5F9));
    });

    test('StaffStatsModel JSON serialization and parsing', () {
      final stats = StaffStatsModel.fromJson({
        'total': 12,
        'active': 9,
        'inactive': 2,
        'admins': 3,
      });

      expect(stats.total, 12);
      expect(stats.active, 9);
      expect(stats.inactive, 2);
      expect(stats.admins, 3);
    });
  });

  group('DatabaseService Staff Operations', () {
    test('DatabaseService pre-populates default staff list and supports CRUD', () {
      final db = DatabaseService();
      expect(db.staffList.isNotEmpty, isTrue);
      expect(db.staffList.length, greaterThanOrEqualTo(8));

      // Test Add
      final newStaff = StaffModel(
        id: 'st_test_999',
        name: 'Test Staff User',
        employeeId: 'EMP999',
        role: 'Cashier',
        status: 'Active',
        createdAt: DateTime.now(),
      );
      db.addStaff(newStaff);
      expect(db.staffList.any((s) => s.id == 'st_test_999'), isTrue);

      // Test Toggle Status
      final toggled = db.toggleStaffStatus('st_test_999');
      expect(toggled?.status, 'Inactive');

      // Test Delete
      db.deleteStaff('st_test_999');
      expect(db.staffList.any((s) => s.id == 'st_test_999'), isFalse);
    });
  });

  group('StaffManagementScreen Widget Tests', () {
    testWidgets('StaffManagementScreen renders title, summary cards, and staff rows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaffManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Header
      expect(find.text('Staff Management'), findsOneWidget);
      expect(find.text('Manage your team, roles and permissions'), findsOneWidget);
      expect(find.text('Create Staff'), findsOneWidget);

      // Verify Metric Cards
      expect(find.text('Total Staff'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Inactive'), findsWidgets);
      expect(find.text('Admins'), findsOneWidget);

      // Verify Table Column Headers & Staff
      expect(find.text('#'), findsOneWidget);
      expect(find.text('Staff Member'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);

      // Verify first seed staff row
      expect(find.text('Amit Sharma'), findsOneWidget);
      expect(find.text('EMP001'), findsOneWidget);
      expect(find.text('Admin'), findsWidgets);
    });
  });

  group('CreateStaffScreen Widget Tests', () {
    testWidgets('CreateStaffScreen renders cards, inputs, no back/cross buttons, and only password in security', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateStaffScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header (Title, Subtitle, View Staff List, no arrow_back or close buttons)
      expect(find.text('Create New Staff'), findsOneWidget);
      expect(find.text('Add a new team member to your business'), findsOneWidget);
      expect(find.text('View Staff List'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      // Verify Basic Information Card
      expect(find.text('Basic Information'), findsOneWidget);
      expect(find.text('Upload Photo'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Employee ID *'), findsOneWidget);
      expect(find.text('Auto-generate'), findsOneWidget);
      expect(find.text('Role *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);

      // Verify Work Details Card
      expect(find.text('Work Details'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Reporting To'), findsOneWidget);
      expect(find.text('Work Location'), findsOneWidget);
      expect(find.text('Shift / Working Hours'), findsOneWidget);

      // Verify Login & Security Card (Password only, NO PIN fields)
      expect(find.text('Login & Security'), findsOneWidget);
      expect(find.text('Set Password *'), findsOneWidget);
      expect(find.text('Confirm Password *'), findsOneWidget);
      expect(find.text('Force password change on first login'), findsOneWidget);
      expect(find.text('Set PIN *'), findsNothing);
      expect(find.text('Confirm PIN *'), findsNothing);
      expect(find.text('4-Digit Quick PIN'), findsNothing);

      // Verify Permissions Card (Categories & Sub-permissions)
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Set what this staff member can access'), findsOneWidget);
      expect(find.text('POS & Orders'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Others'), findsOneWidget);
      expect(find.text('Access POS'), findsOneWidget);
      expect(find.text('Apply Discount'), findsOneWidget);

      // Verify Preferences Card
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Default Screen'), findsOneWidget);
      expect(find.text('Enable Biometric Login'), findsOneWidget);

      // Verify Account Status Card & Footer
      expect(find.text('Account Status'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Last Login'), findsOneWidget);
      expect(find.text('Send welcome email with login details'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Create Staff'), findsOneWidget);
    });
  });

  group('StaffSettingsScreen Widget & Flow Tests', () {
    testWidgets('StaffSettingsScreen renders hero card, 5 tabs, profile fields, and save CTA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));

      final testStaff = StaffModel(
        id: 'st_mock_001',
        name: 'Rahul Verma',
        employeeId: 'EMP002',
        phone: '9876543211',
        email: 'rahul.verma@apnapos.com',
        role: 'Manager',
        status: 'Active',
        department: 'Operations',
        workLocation: 'Main Outlet',
        reportingTo: 'Amit Sharma',
        salary: 35000,
        pin: '1234',
        permissions: const ['pos_access', 'pos_apply_discount', 'pos_manage_tables'],
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffSettingsScreen(
            staff: testStaff,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Bar
      expect(find.text('Staff Settings'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Hero Card
      expect(find.text('Rahul Verma'), findsWidgets);
      expect(find.text('EMP002'), findsWidgets);
      expect(find.text('rahul.verma@apnapos.com'), findsWidgets);
      expect(find.text('Reports to: Amit Sharma'), findsOneWidget);

      // Tab bar tabs
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Work Settings'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);

      // Tab 0 (Profile) contents
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Work Information'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Login & Security'), findsOneWidget);
      expect(find.text('Account Status'), findsOneWidget);
      expect(find.text('Delete Staff'), findsOneWidget);

      // Switch to Tab 1 (Permissions)
      await tester.tap(find.text('Permissions'));
      await tester.pumpAndSettle();

      expect(find.text('POS & Orders'), findsOneWidget);
      expect(find.text('Products & Menu'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Customers & CRM'), findsOneWidget);
      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('Settings & Business'), findsOneWidget);
      expect(find.text('System & Others'), findsOneWidget);
      expect(find.textContaining('Role Presets'), findsOneWidget);

      // Switch to Tab 2 (Work Settings)
      await tester.tap(find.text('Work Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Shift & Compensation'), findsOneWidget);
      expect(find.text('Assigned Shift'), findsOneWidget);
      expect(find.text('Joining Date'), findsOneWidget);

      // Switch to Tab 3 (Security)
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      expect(find.text('Security & Access Control'), findsOneWidget);
      expect(find.text('Reset PIN'), findsOneWidget);
      expect(find.text('Force Password Change on Next Login'), findsOneWidget);

      // Switch to Tab 4 (Activity)
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text('Staff Activity & Audit Trail'), findsOneWidget);
      expect(find.text('Logged into Windows POS Counter'), findsOneWidget);
    });

    testWidgets('Tapping staff row in StaffManagementScreen navigates to StaffSettingsScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffManagementScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify seed staff row exists
      expect(find.text('Amit Sharma'), findsOneWidget);

      // Tap on the Amit Sharma row
      await tester.tap(find.text('Amit Sharma'));
      await tester.pumpAndSettle();

      // Verify Staff Settings screen opened
      expect(find.text('Staff Settings'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.textContaining('Reports to:'), findsOneWidget);
    });
  });
}

