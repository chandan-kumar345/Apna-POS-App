import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/staff_model.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/features/staff/screens/staff_management_screen.dart';

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
        pin: '1111',
        permissions: const ['pos', 'tables', 'orders', 'menu'],
        salary: 25000,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(staff.isActive, isTrue);
      expect(staff.isAdmin, isTrue);
      expect(staff.isCashier, isFalse);
      expect(staff.initials, 'AS');
      expect(staff.roleTextColor, const Color(0xFF7C3AED));
      expect(staff.roleBgColor, const Color(0xFFEDE9FE));

      final json = staff.toJson();
      expect(json['name'], 'Amit Sharma');
      expect(json['employeeId'], 'EMP001');
      expect(json['role'], 'Admin');
      expect(json['status'], 'Active');

      final fromJson = StaffModel.fromJson(json);
      expect(fromJson.name, 'Amit Sharma');
      expect(fromJson.employeeId, 'EMP001');
      expect(fromJson.role, 'Admin');
      expect(fromJson.status, 'Active');
      expect(fromJson.pin, '1111');
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
}
