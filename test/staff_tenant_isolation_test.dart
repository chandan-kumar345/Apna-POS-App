import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/staff_model.dart';
import 'package:apna_pos/core/database/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    db.currentUser = null;
    db.restaurant = null;
    db.staffList.clear();
    db.orders.clear();
    db.menuItems.clear();
  });

  RestaurantModel createTestRestaurant(String id, String name) {
    return RestaurantModel(
      id: id,
      name: name,
      tagline: 'Authentic Flavors',
      phone: '9876543210',
      address: 'Test City',
      cuisineType: 'General',
      currencySymbol: '₹',
      taxRate: 5.0,
      tableCount: 12,
      isOnboarded: true,
    );
  }

  group('Staff Multi-Tenant Isolation Tests', () {
    test('StaffModel serializes and parses businessId correctly', () {
      final staff = StaffModel(
        id: 'st_001',
        name: 'Rahul Sharma',
        employeeId: 'EMP001',
        email: 'rahul@businessa.com',
        role: 'Cashier',
        businessId: 'BUS-A101',
        createdAt: DateTime(2026, 1, 1),
      );

      final json = staff.toJson();
      expect(json['businessId'], equals('BUS-A101'));

      final parsed = StaffModel.fromJson(json);
      expect(parsed.businessId, equals('BUS-A101'));
      expect(parsed.name, equals('Rahul Sharma'));
    });

    test('addStaff stamps currentBusinessId when empty', () async {
      final db = DatabaseService();
      await db.init();
      db.staffList.clear();
      db.currentUser = UserModel(
        id: 'usr_owner_a',
        name: 'Owner A',
        email: 'ownerA@test.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'BUS-ALPHA',
      );

      final staff = StaffModel(
        id: 'st_123',
        name: 'Amit Cashier',
        employeeId: 'EMP123',
        email: 'amit@alpha.com',
        role: 'Cashier',
        createdAt: DateTime(2026, 1, 1),
      );

      db.addStaff(staff);
      expect(db.staffList.length, equals(1));
      expect(db.staffList.first.businessId, equals('BUS-ALPHA'));
    });

    test('syncStaffList rejects staff from other businesses and keeps active tenant only', () async {
      final db = DatabaseService();
      await db.init();
      db.staffList.clear();
      db.currentUser = UserModel(
        id: 'usr_owner_b',
        name: 'Owner B',
        email: 'ownerB@test.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'BUS-BETA',
      );

      final List<StaffModel> remoteStaff = [
        StaffModel(
          id: 'staff_a1',
          name: 'Staff from Biz A',
          employeeId: 'EMP001',
          email: 'staffA@biza.com',
          role: 'Cashier',
          businessId: 'BUS-ALPHA',
          createdAt: DateTime(2026, 1, 1),
        ),
        StaffModel(
          id: 'staff_b1',
          name: 'Staff from Biz B',
          employeeId: 'EMP002',
          email: 'staffB@bizb.com',
          role: 'Manager',
          businessId: 'BUS-BETA',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      db.syncStaffList(remoteStaff);

      // Only staff_b1 for BUS-BETA should be present
      expect(db.staffList.length, equals(1));
      expect(db.staffList.first.id, equals('staff_b1'));
      expect(db.staffList.first.businessId, equals('BUS-BETA'));
      expect(db.staffList.any((s) => s.businessId == 'BUS-ALPHA'), isFalse);
    });

    test('Switching user/business account cleanly isolates and loads only active business staff', () async {
      final db = DatabaseService();
      await db.init();
      db.staffList.clear();

      // 1. Business A Setup
      db.currentUser = UserModel(
        id: 'usr_owner_a',
        name: 'Owner Alpha',
        email: 'alpha@pos.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'BIZ_001',
      );
      db.restaurant = createTestRestaurant('BIZ_001', 'Alpha Restaurant');

      db.addStaff(StaffModel(
        id: 'st_alpha_1',
        name: 'Alpha Chef',
        employeeId: 'EMP_A1',
        email: 'chef@alpha.com',
        role: 'Chef',
        businessId: 'BIZ_001',
        createdAt: DateTime(2026, 1, 1),
      ));

      expect(db.staffList.length, equals(1));
      expect(db.staffList.first.name, equals('Alpha Chef'));

      // 2. Switch to Business B
      db.currentUser = UserModel(
        id: 'usr_owner_b',
        name: 'Owner Beta',
        email: 'beta@pos.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'BIZ_002',
      );
      db.restaurant = createTestRestaurant('BIZ_002', 'Beta Cafe');

      // Load user data for Business B
      await db.loadUserDataForActiveUser('usr_owner_b');

      // In-memory staff list should NOT have Alpha's staff
      expect(db.staffList.any((s) => s.businessId == 'BIZ_001'), isFalse);
      expect(db.staffList.isEmpty, isTrue);

      // Add Beta staff
      db.addStaff(StaffModel(
        id: 'st_beta_1',
        name: 'Beta Barista',
        employeeId: 'EMP_B1',
        email: 'barista@beta.com',
        role: 'Cashier',
        businessId: 'BIZ_002',
        createdAt: DateTime(2026, 1, 1),
      ));

      expect(db.staffList.length, equals(1));
      expect(db.staffList.first.name, equals('Beta Barista'));

      // 3. Switch back to Business A
      db.currentUser = UserModel(
        id: 'usr_owner_a',
        name: 'Owner Alpha',
        email: 'alpha@pos.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'BIZ_001',
      );
      db.restaurant = createTestRestaurant('BIZ_001', 'Alpha Restaurant');

      await db.loadUserDataForActiveUser('usr_owner_a');

      // Alpha's staff should be restored and Beta's staff should NOT appear
      expect(db.staffList.length, equals(1));
      expect(db.staffList.first.name, equals('Alpha Chef'));
      expect(db.staffList.first.businessId, equals('BIZ_001'));
      expect(db.staffList.any((s) => s.businessId == 'BIZ_002'), isFalse);
    });

    test('clearUserDataForNewAccount purges staffList and all business-scoped staff keys', () async {
      final db = DatabaseService();
      await db.init();
      db.staffList.clear();

      db.currentUser = UserModel(
        id: 'usr_temp',
        name: 'Temp User',
        email: 'temp@pos.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'BIZ_TEMP',
      );

      db.addStaff(StaffModel(
        id: 'st_temp_1',
        name: 'Temp Waiter',
        employeeId: 'EMP_T1',
        role: 'Waiter',
        createdAt: DateTime(2026, 1, 1),
      ));

      expect(db.staffList.length, equals(1));

      await db.clearUserDataForNewAccount();

      expect(db.staffList.isEmpty, isTrue);
    });
  });
}
