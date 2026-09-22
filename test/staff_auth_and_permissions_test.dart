import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/models/user_model.dart';
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
      expect(db.currentUser?.hasPermission('pos'), isTrue); // orders maps to pos category
      expect(db.currentUser?.hasPermission('staff'), isFalse);
      expect(db.currentUser?.hasPermission('settings'), isFalse);
    });
  });
}
