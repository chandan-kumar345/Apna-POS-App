import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/staff_model.dart';
import 'package:apna_pos/core/database/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserModel Role & Permission Tests', () {
    test('Owner and Admin have wildcard access to all features', () {
      final owner = UserModel(
        id: 'usr_001',
        name: 'Store Owner',
        email: 'owner@apnapos.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'rest_001',
        permissions: ['*'],
      );

      expect(owner.isOwner, isTrue);
      expect(owner.isAdmin, isTrue);
      expect(owner.hasPermission('pos'), isTrue);
      expect(owner.hasPermission('inventory'), isTrue);
      expect(owner.hasPermission('reports'), isTrue);
      expect(owner.hasPermission('settings'), isTrue);
      expect(owner.hasPermission('staff'), isTrue);
      expect(owner.hasPermission('crm'), isTrue);
      expect(owner.hasPermission('campaign'), isTrue);
      expect(owner.hasPermission('loyalty'), isTrue);

      final admin = UserModel(
        id: 'usr_002',
        name: 'Store Admin',
        email: 'admin@apnapos.com',
        role: 'Admin',
        pin: '1234',
        restaurantId: 'rest_001',
        permissions: ['*'],
      );

      expect(admin.isOwner, isFalse);
      expect(admin.isAdmin, isTrue);
      expect(admin.hasPermission('pos'), isTrue);
      expect(admin.hasPermission('inventory'), isTrue);
      expect(admin.hasPermission('reports'), isTrue);
    });

    test('Cashier has scoped access to POS, Tables, Orders only', () {
      final cashier = UserModel(
        id: 'usr_003',
        name: 'Ravi Cashier',
        email: 'ravi@apnapos.com',
        role: 'Cashier',
        employeeId: 'EMP003',
        pin: '1234',
        restaurantId: 'rest_001',
        permissions: const ['pos', 'tables', 'orders'],
      );

      expect(cashier.isCashier, isTrue);
      expect(cashier.isAdmin, isFalse);
      expect(cashier.isOwner, isFalse);
      expect(cashier.hasPermission('pos'), isTrue);
      expect(cashier.hasPermission('tables'), isTrue);
      expect(cashier.hasPermission('orders'), isTrue);
      expect(cashier.hasPermission('inventory'), isFalse);
      expect(cashier.hasPermission('reports'), isFalse);
      expect(cashier.hasPermission('staff'), isFalse);
      expect(cashier.hasPermission('settings'), isFalse);
    });

    test('Granular sub-permission keys map correctly to module categories', () {
      final staff = UserModel(
        id: 'usr_004',
        name: 'Sunil Staff',
        email: 'sunil@apnapos.com',
        role: 'Manager',
        pin: '1234',
        restaurantId: 'rest_001',
        permissions: const [
          'pos_access',
          'pos_manage_tables',
          'inventory_view',
          'reports_daily_sales',
          'settings_staff',
        ],
      );

      expect(staff.hasPermission('pos'), isTrue);
      expect(staff.hasPermission('tables'), isTrue);
      expect(staff.hasPermission('inventory'), isTrue);
      expect(staff.hasPermission('reports'), isTrue);
      expect(staff.hasPermission('staff'), isTrue);
      expect(staff.hasPermission('campaign'), isFalse);
      expect(staff.hasPermission('loyalty'), isFalse);
    });

    test('UserModel JSON serialization preserves permissions and employeeId', () {
      final user = UserModel(
        id: 'usr_005',
        name: 'Pooja Waiter',
        email: 'pooja@apnapos.com',
        role: 'Waiter',
        employeeId: 'EMP005',
        pin: '1234',
        restaurantId: 'rest_001',
        permissions: const ['pos', 'tables'],
      );

      final json = user.toJson();
      expect(json['employeeId'], 'EMP005');
      expect(json['permissions'], ['pos', 'tables']);

      final restored = UserModel.fromJson(json);
      expect(restored.employeeId, 'EMP005');
      expect(restored.permissions, ['pos', 'tables']);
      expect(restored.hasPermission('pos'), isTrue);
      expect(restored.hasPermission('inventory'), isFalse);
    });

    test('DatabaseService switches active user and reflects permissions', () async {
      final db = DatabaseService();
      final staffUser = UserModel(
        id: 'usr_switch_01',
        name: 'Karan Chef',
        email: 'karan@apnapos.com',
        role: 'Chef',
        employeeId: 'EMP007',
        pin: '1234',
        restaurantId: 'rest_001',
        permissions: const ['orders', 'menu'],
      );

      await db.saveActiveUser(staffUser);
      expect(db.currentUser?.id, 'usr_switch_01');
      expect(db.currentUser?.employeeId, 'EMP007');
      expect(db.currentUser?.isChef, isTrue);
      expect(db.currentUser?.hasPermission('orders'), isTrue);
      expect(db.currentUser?.hasPermission('menu'), isTrue);
      expect(db.currentUser?.hasPermission('pos'), isFalse); // Strict isolation: orders alone does not grant pos
      expect(db.currentUser?.hasPermission('staff'), isFalse);
      expect(db.currentUser?.hasPermission('settings'), isFalse);
    });

    test('Strict permission isolation: POS only staff has no access to tables, orders, inventory', () {
      final posOnlyUser = UserModel(
        id: 'usr_pos_only',
        name: 'Sneha Cashier',
        email: 'sneha@apnapos.com',
        role: 'Cashier',
        employeeId: 'EMP007',
        pin: '7777',
        restaurantId: 'rest_001',
        permissions: const ['pos'],
      );

      expect(posOnlyUser.hasPermission('pos'), isTrue);
      expect(posOnlyUser.hasPermission('tables'), isFalse);
      expect(posOnlyUser.hasPermission('orders'), isFalse);
      expect(posOnlyUser.hasPermission('dashboard'), isFalse);
      expect(posOnlyUser.hasPermission('inventory'), isFalse);
      expect(posOnlyUser.hasPermission('reports'), isFalse);
      expect(posOnlyUser.hasPermission('crm'), isFalse);
      expect(posOnlyUser.hasPermission('loyalty'), isFalse);
      expect(posOnlyUser.hasPermission('campaign'), isFalse);
      expect(posOnlyUser.hasPermission('staff'), isFalse);
      expect(posOnlyUser.hasPermission('settings'), isFalse);
    });

    test('Owner creates new staff with avatar photo and permissions, and staff login reflects all details', () async {
      final db = DatabaseService();
      
      // 1. Owner creates a new staff member (e.g. Rohit Kumar - POS and Takeaway Cashier)
      final createdStaff = StaffModel(
        id: 'st_rohit_009',
        name: 'Rohit Kumar',
        employeeId: 'EMP009',
        email: 'rohit@apnapos.com',
        phone: '+91 9876543210',
        role: 'Cashier',
        status: 'Active',
        pin: '9999',
        avatarUrl: '/path/to/rohit_photo.png',
        department: 'Billing / Counter',
        defaultScreen: 'POS Billing',
        permissions: const ['pos_access', 'pos_apply_discount', 'pos_takeaway_delivery', 'customers_view'],
        createdAt: DateTime.now(),
      );

      db.addStaff(createdStaff);
      expect(db.staffList.any((s) => s.employeeId == 'EMP009'), isTrue);

      // 2. Staff logs in using Employee ID 'EMP009' and PIN '9999'
      final matched = db.staffList.firstWhere((s) => s.employeeId == 'EMP009');
      final loggedInUser = UserModel(
        id: matched.id,
        name: matched.name,
        email: matched.email,
        role: matched.role,
        pin: matched.pin,
        restaurantId: 'rest_001',
        phone: matched.phone,
        employeeId: matched.employeeId,
        profilePhotoPath: matched.avatarUrl,
        permissions: matched.permissions,
        jobTitle: matched.role,
        onboardingCompleted: true,
        onboardingStep: 4,
      );

      await db.saveActiveUser(loggedInUser);

      // Verify all staff details are accurately present in the logged-in session
      expect(db.currentUser?.name, 'Rohit Kumar');
      expect(db.currentUser?.employeeId, 'EMP009');
      expect(db.currentUser?.role, 'Cashier');
      expect(db.currentUser?.profilePhotoPath, '/path/to/rohit_photo.png');
      expect(db.currentUser?.phone, '+91 9876543210');
      expect(db.currentUser?.email, 'rohit@apnapos.com');

      // Verify dynamic permission enforcement for this newly created staff
      expect(db.currentUser?.hasPermission('pos'), isTrue);
      expect(db.currentUser?.hasPermission('crm'), isTrue); // customers_view maps to crm
      expect(db.currentUser?.hasPermission('tables'), isFalse);
      expect(db.currentUser?.hasPermission('orders'), isFalse);
      expect(db.currentUser?.hasPermission('inventory'), isFalse);
      expect(db.currentUser?.hasPermission('reports'), isFalse);
      expect(db.currentUser?.hasPermission('staff'), isFalse);
      expect(db.currentUser?.hasPermission('settings'), isFalse);
    });

    test('Staff update in DatabaseService dynamically synchronizes avatar and permissions in real-time', () async {
      final db = DatabaseService();
      final staffUser = UserModel(
        id: 'staff_sync_01',
        name: 'Sunita Waiter',
        email: 'sunita@apnapos.com',
        role: 'Waiter',
        employeeId: 'EMP004',
        pin: '4444',
        restaurantId: 'rest_001',
        profilePhotoPath: '/old/path.png',
        permissions: const ['pos_view_all_orders'],
      );

      await db.saveActiveUser(staffUser);
      expect(db.currentUser?.hasPermission('orders'), isTrue);
      expect(db.currentUser?.hasPermission('pos'), isFalse);
      expect(db.currentUser?.profilePhotoPath, '/old/path.png');

      // Store owner updates Sunita's avatar photo and adds table management permission
      final updatedStaff = db.staffList.firstWhere((s) => s.employeeId == 'EMP004').copyWith(
        avatarUrl: '/new/sunita_headshot.jpg',
        permissions: const ['pos_view_all_orders', 'pos_manage_tables'],
      );
      db.updateStaff(updatedStaff);

      expect(db.currentUser?.profilePhotoPath, '/new/sunita_headshot.jpg');
      expect(db.currentUser?.hasPermission('orders'), isTrue);
      expect(db.currentUser?.hasPermission('tables'), isTrue);
      expect(db.currentUser?.hasPermission('pos'), isFalse);
    });
  });
}
