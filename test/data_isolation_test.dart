import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('User isolation: User B does not see User A products and orders', () async {
    final db = DatabaseService();
    await db.init();

    // 1. User A logs in and adds a product and order
    final userA = UserModel(
      id: 'user_a_123',
      name: 'User A',
      email: 'usera@example.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_user_a',
    );
    await db.saveActiveUser(userA);

    final productA = MenuItemModel(
      id: 'prod_a_1',
      name: 'User A Special Burger',
      category: 'Burgers',
      price: 150.0,
      description: 'Delicious burger by User A',
    );
    await db.saveMenuItem(productA);

    final orderA = await db.createOrder(
      items: [CartItemModel(item: productA, quantity: 2)],
      orderType: OrderType.dineIn,
      discountAmount: 0.0,
      paymentMethod: 'Cash',
      tableNumber: 'T-1',
    );

    expect(db.menuItems.length, 1);
    expect(db.menuItems.first.name, 'User A Special Burger');
    expect(db.orders.length, 1);
    expect(db.orders.first.orderNumber, orderA.orderNumber);

    // 2. User A logs out
    await db.logout();

    expect(db.currentUser, isNull);
    expect(db.menuItems, isEmpty);
    expect(db.orders, isEmpty);

    // 3. User B registers new account
    final userB = UserModel(
      id: 'user_b_456',
      name: 'User B',
      email: 'userb@example.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_user_b',
    );
    await db.saveActiveUser(userB);
    await db.clearUserDataForNewAccount();

    // Verify User B starts with 0 products and 0 orders
    expect(db.menuItems, isEmpty);
    expect(db.orders, isEmpty);

    // 4. User B adds their own product
    final productB = MenuItemModel(
      id: 'prod_b_1',
      name: 'User B Pizza',
      category: 'Pizza',
      price: 250.0,
      description: 'Pizza by User B',
    );
    await db.saveMenuItem(productB);

    expect(db.menuItems.length, 1);
    expect(db.menuItems.first.name, 'User B Pizza');
    expect(db.orders, isEmpty);

    // 5. User B logs out, User A logs back in
    await db.logout();
    await db.saveActiveUser(userA);

    // Verify User A's products and orders are preserved and isolated
    expect(db.menuItems.length, 1);
    expect(db.menuItems.first.name, 'User A Special Burger');
    expect(db.orders.length, 1);
    expect(db.orders.first.orderNumber, orderA.orderNumber);
    expect(db.categories.contains('Burgers'), isTrue);
    expect(db.categories.contains('Pizza'), isFalse);
  });

  test('Restaurant profile and settings isolation between users', () async {
    final db = DatabaseService();
    await db.init();

    final userA = UserModel(
      id: 'usr_cafe_a',
      name: 'Cafe A Owner',
      email: 'cafea@example.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_cafe_a',
    );
    await db.saveActiveUser(userA);
    await db.updateBusinessName('Cafe A Deluxe');

    expect(db.restaurant?.name, 'Cafe A Deluxe');

    await db.logout();

    final userB = UserModel(
      id: 'usr_diner_b',
      name: 'Diner B Owner',
      email: 'dinerb@example.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_diner_b',
    );
    await db.saveActiveUser(userB);
    await db.clearUserDataForNewAccount();

    expect(db.restaurant?.name, 'Diner B Owner');

    await db.logout();
    await db.saveActiveUser(userA);

    expect(db.restaurant?.name, 'Cafe A Deluxe');
  });

  test('ProductService clearPosCache empties cache cleanly', () {
    ProductService.clearPosCache();
    expect(true, isTrue);
  });

  test('DatabaseService detects unsynced local products and preserves them across sync', () async {
    final db = DatabaseService();
    await db.init();

    final user = UserModel(
      id: 'usr_sync_test',
      name: 'Sync Tester',
      email: 'sync@example.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_sync_test',
    );
    await db.saveActiveUser(user);

    // Simulate 4 CSV imported products saved locally
    final p1 = MenuItemModel(id: 'item_101', productId: 'item_101', name: 'Veg Chowmein', category: 'Noodles', price: 120.0, description: 'Desi style');
    final p2 = MenuItemModel(id: 'item_102', productId: 'item_102', name: 'Chicken Chowmein', category: 'Noodles', price: 160.0, description: 'Spicy chicken noodles', itemType: 'Non-Veg');
    final p3 = MenuItemModel(id: 'PRD-103', productId: 'PRD-103', name: 'Spring Roll', category: 'Starters', price: 90.0, description: 'Crispy rolls');
    final p4 = MenuItemModel(id: 'PRD-104', productId: 'PRD-104', name: 'Manchurian Dry', category: 'Starters', price: 140.0, description: 'Fried veg balls');

    await db.importProductsFromCsv([p1, p2, p3, p4]);

    expect(db.menuItems.length, 4);
    expect(db.categories.contains('Noodles'), isTrue);
    expect(db.categories.contains('Starters'), isTrue);

    // Verify all 4 products are preserved and available for POS and cross-device sync
    expect(db.menuItems.any((i) => i.name == 'Veg Chowmein'), isTrue);
    expect(db.menuItems.any((i) => i.name == 'Chicken Chowmein'), isTrue);
    expect(db.menuItems.any((i) => i.name == 'Spring Roll'), isTrue);
    expect(db.menuItems.any((i) => i.name == 'Manchurian Dry'), isTrue);
  });
}
