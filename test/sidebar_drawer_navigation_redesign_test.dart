import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/staff_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/core/widgets/glass_company_name_badge.dart';
import 'package:apna_pos/features/dashboard/main_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;

  setUp(() async {
    SoundService.soundEnabled = false;
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    await db.init();
    db.currentUser = UserModel(
      id: 'owner_01',
      name: 'chandan kumar',
      email: 'owner@apnapos.com',
      phone: '9999999999',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_01',
    );
    db.restaurant = RestaurantModel(
      id: 'rest_01',
      name: 'Tea Coffee',
      tagline: 'Fresh & Fast',
      phone: '9999999999',
      address: 'Main Street',
      cuisineType: 'Cafe',
      currencySymbol: '₹',
      taxRate: 5.0,
      billingType: 'GST',
    );
  });

  tearDown(() {
    NetworkService().dispose();
  });

  testWidgets('Sidebar Drawer Navigation Redesign renders all items and visual styles', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(600, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: MainLayout(),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      // Tap header company badge / drawer toggle to open sidebar
      final headerToggle = find.byType(InkWell).first;
      await tester.tap(headerToggle);
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 400));
      await tester.pump();

      // Verify main navigation items are present
      expect(find.text('Staff Profile'), findsWidgets);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('POS'), findsWidgets);
      expect(find.text('Tables'), findsWidgets);
      expect(find.text('My Orders'), findsWidgets);
      expect(find.text('Menu & Categories'), findsWidgets);
      expect(find.text('Inventory'), findsWidgets);
      expect(find.text('Sales Report'), findsWidgets);
      expect(find.text('CRM'), findsWidgets);
      expect(find.text('Loyalty'), findsWidgets);
      expect(find.text('Campaign'), findsWidgets);
      expect(find.text('Staff Setting'), findsWidgets);
      expect(find.text('Business Setting'), findsWidgets);

      // Verify user profile footer
      expect(find.text('chandan kumar'), findsWidgets);
      expect(find.text('Owner'), findsWidgets);
      expect(find.byIcon(Icons.logout_rounded), findsWidgets);
    });
  });

  testWidgets('Company name badge shows dropdown arrow when staff exists and handles profile switching', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(600, 900));

      // 1. When staffList is empty
      db.staffList.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: MainLayout(),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      // Dropdown chevron icon should NOT exist when staffList is empty
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      // 2. Add staff to staffList
      db.staffList.add(
        StaffModel(
          id: 'staff_01',
          name: 'Rahul Sharma',
          employeeId: 'EMP001',
          role: 'Cashier',
          status: 'Active',
          permissions: const ['pos', 'tables', 'orders'],
          createdAt: DateTime.now(),
        ),
      );
      db.notifyListeners();

      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      // Dropdown chevron icon SHOULD now be visible
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Tap the company name badge with dropdown
      await tester.tap(find.byType(GlassCompanyNameBadge));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the profile switcher modal popup is shown
      expect(find.text('Switch Profile / Staff'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('ID: EMP001'), findsOneWidget);

      // Tap on Rahul Sharma to switch to this staff member
      await tester.tap(find.text('Rahul Sharma'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Current user in DatabaseService should now be the staff user
      expect(db.currentUser?.name, 'Rahul Sharma');
      expect(db.currentUser?.role, 'Cashier');
      expect(db.isLoggedInAsStaff, isTrue);

      // Open sidebar again to check footer profile reflection
      final headerToggle = find.byType(InkWell).first;
      await tester.tap(headerToggle);
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Rahul Sharma'), findsWidgets);
      expect(find.textContaining('Cashier'), findsWidgets);

      // Switch back to Owner
      await db.switchToOwner();
      expect(db.currentUser?.name, 'chandan kumar');
      expect(db.currentUser?.role, 'Owner');
      expect(db.isLoggedInAsStaff, isFalse);
    });
  });
}

