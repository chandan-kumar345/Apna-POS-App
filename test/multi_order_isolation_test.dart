import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/features/pos/pos_register_screen.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    await db.init();
    db.loadUserDataForActiveUser('test_user_isolation');

    db.currentUser = UserModel(
      id: 'owner_01',
      name: 'Owner Name',
      email: 'owner@apnapos.com',
      phone: '9999999999',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_01',
    );

    db.restaurant = RestaurantModel(
      id: 'rest_01',
      name: 'Shri Sai Cafe',
      tagline: 'Fresh & Tasty',
      phone: '9876543210',
      address: 'Shop 4, Market',
      cuisineType: 'Cafe',
      currencySymbol: '₹',
      billingType: 'Non-GST',
      posViewMode: 'with_image',
    );

    // Seed dummy tables
    db.tables.clear();
    db.tables.addAll([
      TableModel(id: 'tbl_1', tableNumber: 1, name: 'Table 1', floor: 'Ground', capacity: 4, status: TableStatus.free),
      TableModel(id: 'tbl_2', tableNumber: 2, name: 'Table 2', floor: 'Ground', capacity: 4, status: TableStatus.free),
      TableModel(id: 'tbl_3', tableNumber: 3, name: 'Table 3', floor: '1st Floor', capacity: 6, status: TableStatus.free),
    ]);

    // Seed menu items
    db.menuItems.clear();
    db.categories.clear();
    db.categories.addAll(['Burgers', 'Pizza']);
    db.menuItems.addAll([
      MenuItemModel(
        id: 'item_burger',
        name: 'Veg Burger',
        category: 'Burgers',
        price: 120.0,
        description: 'Delicious veg burger',
        itemType: 'Veg',
        isAvailable: true,
      ),
      MenuItemModel(
        id: 'item_pizza',
        name: 'Margherita Pizza',
        category: 'Pizza',
        price: 250.0,
        description: 'Cheesy margherita pizza',
        itemType: 'Veg',
        isAvailable: true,
      ),
    ]);
  });

  group('Multi-Order & Multi-Table Draft Isolation Tests', () {
    final itemBurger = MenuItemModel(
      id: 'item_burger',
      name: 'Veg Burger',
      category: 'Burgers',
      price: 120.0,
      description: 'Delicious veg burger',
      itemType: 'Veg',
    );

    final itemPizza = MenuItemModel(
      id: 'item_pizza',
      name: 'Margherita Pizza',
      category: 'Pizza',
      price: 250.0,
      description: 'Cheesy margherita pizza',
      itemType: 'Veg',
    );

    final itemPasta = MenuItemModel(
      id: 'item_pasta',
      name: 'White Sauce Pasta',
      category: 'Pasta',
      price: 180.0,
      description: 'Creamy white sauce pasta',
      itemType: 'Veg',
    );

    final itemCoke = MenuItemModel(
      id: 'item_coke',
      name: 'Cold Drink',
      category: 'Beverages',
      price: 40.0,
      description: 'Refreshing chilled cola',
      itemType: 'Beverage',
    );

    test('Isolated drafts across multiple tables, Takeaway, and Delivery simultaneously', () async {
      // 1. Customer 1 on Table 1
      final cartT1 = [
        CartItemModel(item: itemBurger, quantity: 2), // 240
      ];
      db.setLiveTableCart('Table 1', cartT1);
      db.setLiveCartTotal('Table 1', 240.0);
      db.setLiveCustomerInfo('Table 1', name: 'Alice Smith', phone: '9876543210');
      db.setLiveTableDiscount('Table 1', coupon: 'SAVE10', discountInput: 10.0, discountMode: 'percent', discountAmount: 24.0);

      // 2. Customer 2 on Table 2
      final cartT2 = [
        CartItemModel(item: itemPizza, quantity: 1), // 250
        CartItemModel(item: itemCoke, quantity: 2),   // 80
      ];
      db.setLiveTableCart('Table 2', cartT2);
      db.setLiveCartTotal('Table 2', 330.0);
      db.setLiveCustomerInfo('Table 2', name: 'Bob Jones', phone: '9123456780');

      // 3. Customer 3 on Takeaway
      final cartTakeaway = [
        CartItemModel(item: itemPasta, quantity: 1), // 180
      ];
      db.setLiveTableCart('Takeaway', cartTakeaway);
      db.setLiveCartTotal('Takeaway', 180.0);
      db.setLiveCustomerInfo('Takeaway', name: 'Charlie Brown', phone: '9988776655');

      // 4. Customer 4 on Delivery
      final cartDelivery = [
        CartItemModel(item: itemBurger, quantity: 3), // 360
        CartItemModel(item: itemCoke, quantity: 3),   // 120
      ];
      db.setLiveTableCart('Delivery', cartDelivery);
      db.setLiveCartTotal('Delivery', 480.0);
      db.setLiveCustomerInfo('Delivery', name: 'Diana Prince', phone: '9112233445');
      db.setLiveDeliveryInfo(
        'Delivery',
        address: 'Flat 402, Sunshine Heights',
        landmark: 'Near City Park',
        city: 'New Delhi',
        state: 'Delhi',
        pincode: '110001',
      );

      // --- VERIFY ISOLATION FOR TABLE 1 ---
      final loadedT1Cart = db.getLiveTableCart('Table 1');
      expect(loadedT1Cart.length, 1);
      expect(loadedT1Cart.first.item.name, 'Veg Burger');
      expect(loadedT1Cart.first.quantity, 2);
      expect(db.getLiveCartTotal('Table 1'), 240.0);
      final loadedT1Cust = db.getLiveCustomerInfo('Table 1');
      expect(loadedT1Cust?['name'], 'Alice Smith');
      expect(loadedT1Cust?['phone'], '9876543210');
      final loadedT1Disc = db.getLiveTableDiscount('Table 1');
      expect(loadedT1Disc?['coupon'], 'SAVE10');
      expect(loadedT1Disc?['discountAmount'], 24.0);

      // --- VERIFY ISOLATION FOR TABLE 2 ---
      final loadedT2Cart = db.getLiveTableCart('Table 2');
      expect(loadedT2Cart.length, 2);
      expect(loadedT2Cart[0].item.name, 'Margherita Pizza');
      expect(loadedT2Cart[1].item.name, 'Cold Drink');
      expect(db.getLiveCartTotal('Table 2'), 330.0);
      final loadedT2Cust = db.getLiveCustomerInfo('Table 2');
      expect(loadedT2Cust?['name'], 'Bob Jones');
      expect(loadedT2Cust?['phone'], '9123456780');
      expect(db.getLiveTableDiscount('Table 2'), isNull);

      // --- VERIFY ISOLATION FOR TAKEAWAY ---
      final loadedTakeawayCart = db.getLiveTableCart('Takeaway');
      expect(loadedTakeawayCart.length, 1);
      expect(loadedTakeawayCart.first.item.name, 'White Sauce Pasta');
      expect(db.getLiveCartTotal('Takeaway'), 180.0);
      final loadedTakeawayCust = db.getLiveCustomerInfo('Takeaway');
      expect(loadedTakeawayCust?['name'], 'Charlie Brown');
      expect(loadedTakeawayCust?['phone'], '9988776655');

      // --- VERIFY ISOLATION FOR DELIVERY ---
      final loadedDeliveryCart = db.getLiveTableCart('Delivery');
      expect(loadedDeliveryCart.length, 2);
      expect(db.getLiveCartTotal('Delivery'), 480.0);
      final loadedDeliveryCust = db.getLiveCustomerInfo('Delivery');
      expect(loadedDeliveryCust?['name'], 'Diana Prince');
      expect(loadedDeliveryCust?['phone'], '9112233445');
      final loadedDeliveryAddress = db.getLiveDeliveryInfo('Delivery');
      expect(loadedDeliveryAddress?['address'], 'Flat 402, Sunshine Heights');
      expect(loadedDeliveryAddress?['landmark'], 'Near City Park');
      expect(loadedDeliveryAddress?['city'], 'New Delhi');
      expect(loadedDeliveryAddress?['pincode'], '110001');

      // Table 1 lookup using alias "T-1" or "T1" must resolve normalized
      expect(db.getLiveCustomerInfo('T-1')?['name'], 'Alice Smith');
      expect(db.getLiveCustomerInfo('T1')?['name'], 'Alice Smith');
    });

    test('Settling Table 1 frees Table 1 and wipes only Table 1 draft, keeping Table 2 & Delivery intact', () async {
      // Setup Table 1, Table 2, Takeaway, Delivery
      db.setLiveTableCart('Table 1', [CartItemModel(item: itemBurger, quantity: 1)]);
      db.setLiveCustomerInfo('Table 1', name: 'Alice', phone: '1111111111');
      db.updateTableStatus('tbl_1', TableStatus.occupied);

      db.setLiveTableCart('Table 2', [CartItemModel(item: itemPizza, quantity: 1)]);
      db.setLiveCustomerInfo('Table 2', name: 'Bob', phone: '2222222222');
      db.updateTableStatus('tbl_2', TableStatus.occupied);

      db.setLiveTableCart('Delivery', [CartItemModel(item: itemPasta, quantity: 1)]);
      db.setLiveCustomerInfo('Delivery', name: 'Diana', phone: '3333333333');

      // Settle and free Table 1
      db.clearTableCartAndFree('Table 1');

      // Verify Table 1 is cleared & free
      expect(db.getLiveTableCart('Table 1'), isEmpty);
      expect(db.getLiveCustomerInfo('Table 1'), isNull);
      expect(db.tables.firstWhere((t) => t.name == 'Table 1').status, TableStatus.free);

      // Verify Table 2 is untouched
      expect(db.getLiveTableCart('Table 2').length, 1);
      expect(db.getLiveCustomerInfo('Table 2')?['name'], 'Bob');
      expect(db.tables.firstWhere((t) => t.name == 'Table 2').status, TableStatus.occupied);

      // Verify Delivery is untouched
      expect(db.getLiveTableCart('Delivery').length, 1);
      expect(db.getLiveCustomerInfo('Delivery')?['name'], 'Diana');
    });

    test('shiftTableData transfers items, customer info, delivery info, and discount to target table', () async {
      db.setLiveTableCart('Table 1', [CartItemModel(item: itemBurger, quantity: 2)]);
      db.setLiveCartTotal('Table 1', 240.0);
      db.setLiveCustomerInfo('Table 1', name: 'Alice Smith', phone: '9876543210');
      db.setLiveTableDiscount('Table 1', coupon: 'SAVE10', discountInput: 10.0, discountMode: 'percent', discountAmount: 24.0);
      db.updateTableStatus('tbl_1', TableStatus.occupied, occupiedSince: '2026-10-08T10:00:00.000Z');

      // Shift Table 1 -> Table 3
      db.shiftTableData('Table 1', 'Table 3');

      // Source Table 1 must be cleared and free
      expect(db.getLiveTableCart('Table 1'), isEmpty);
      expect(db.getLiveCustomerInfo('Table 1'), isNull);
      expect(db.getLiveTableDiscount('Table 1'), isNull);
      expect(db.tables.firstWhere((t) => t.name == 'Table 1').status, TableStatus.free);

      // Target Table 3 must have all Table 1 data
      final shiftedCart = db.getLiveTableCart('Table 3');
      expect(shiftedCart.length, 1);
      expect(shiftedCart.first.item.name, 'Veg Burger');
      expect(db.getLiveCustomerInfo('Table 3')?['name'], 'Alice Smith');
      expect(db.getLiveCustomerInfo('Table 3')?['phone'], '9876543210');
      expect(db.getLiveTableDiscount('Table 3')?['coupon'], 'SAVE10');
      expect(db.tables.firstWhere((t) => t.name == 'Table 3').status, TableStatus.occupied);
    });

    testWidgets('PosRegisterScreen table switching preserves drafts across tables', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final posKey = GlobalKey();

      await tester.pumpWidget(MaterialApp(
        home: PosRegisterScreen(key: posKey, initialTable: 'Table 1'),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Add item on Table 1
      final addButtons = find.widgetWithText(ElevatedButton, 'Add');
      expect(addButtons, findsWidgets);
      await tester.tap(addButtons.first);
      await tester.pump(const Duration(milliseconds: 300));

      // Table 1 cart should have item
      expect(db.getLiveTableCart('Table 1').length, 1);
      expect(db.getLiveTableCart('Table 1').first.item.name, 'Veg Burger');

      // 2. Switch to Table 2 via initialTable property update
      await tester.pumpWidget(MaterialApp(
        home: PosRegisterScreen(key: posKey, initialTable: 'Table 2', tableSelectionToken: 2),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Add Pizza to Table 2
      final pizzaAdd = find.widgetWithText(ElevatedButton, 'Add');
      await tester.tap(pizzaAdd.last);
      await tester.pump(const Duration(milliseconds: 300));

      // Table 2 cart should have Pizza
      expect(db.getLiveTableCart('Table 2').length, 1);
      expect(db.getLiveTableCart('Table 2').first.item.name, 'Margherita Pizza');

      // Table 1 cart must still have Veg Burger!
      expect(db.getLiveTableCart('Table 1').length, 1);
      expect(db.getLiveTableCart('Table 1').first.item.name, 'Veg Burger');

      // 3. Switch back to Table 1
      await tester.pumpWidget(MaterialApp(
        home: PosRegisterScreen(key: posKey, initialTable: 'Table 1', tableSelectionToken: 3),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Table 1 cart must still have Veg Burger and Table 2 must still have Pizza!
      expect(db.getLiveTableCart('Table 1').length, 1);
      expect(db.getLiveTableCart('Table 1').first.item.name, 'Veg Burger');
      expect(db.getLiveTableCart('Table 2').length, 1);
      expect(db.getLiveTableCart('Table 2').first.item.name, 'Margherita Pizza');
    });

    testWidgets('Switching to another table when first table is occupied with orders loads target table cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Create an active order for Table 1
      final order1 = await db.createOrder(
        items: [
          CartItemModel(item: itemBurger, quantity: 2),
        ],
        tableNumber: 'Table 1',
        orderType: OrderType.dineIn,
        discountAmount: 0.0,
        paymentMethod: 'KOT Pending',
        status: OrderStatus.preparing,
      );
      expect(db.orders.length, 1);
      expect(db.tables.firstWhere((t) => t.name == 'Table 1').status, TableStatus.runningKot);

      final posKey = GlobalKey();

      // Start on Table 1
      await tester.pumpWidget(MaterialApp(
        home: PosRegisterScreen(
          key: posKey,
          initialTable: 'Table 1',
          initialOrderType: OrderType.dineIn,
          tableSelectionToken: 1,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 2. Select Table 2 as from Tables tab (with initialTable 'Table 2', initialOrderType: OrderType.dineIn)
      await tester.pumpWidget(MaterialApp(
        home: PosRegisterScreen(
          key: posKey,
          initialTable: 'Table 2',
          initialOrderType: OrderType.dineIn,
          tableSelectionToken: 2,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Add item for Table 2
      final addButtons = find.widgetWithText(ElevatedButton, 'Add');
      await tester.tap(addButtons.last); // Pizza
      await tester.pump(const Duration(milliseconds: 300));

      // Table 2 cart should now have Pizza
      expect(db.getLiveTableCart('Table 2').length, 1);
      expect(db.getLiveTableCart('Table 2').first.item.name, 'Margherita Pizza');

      // Table 1 active order should still be intact
      final orderOnT1 = db.orders.firstWhere((o) => o.tableNumber == 'Table 1');
      expect(orderOnT1.id, order1.id);
      expect(orderOnT1.items.length, 1);
      expect(orderOnT1.items.first.item.name, 'Veg Burger');
    });

    test('Table updates (name, floor, capacity, tableNumber) are persisted in DatabaseService', () async {
      final initialTable = db.tables.firstWhere((t) => t.name == 'Table 1');
      expect(initialTable.floor, 'Ground');
      expect(initialTable.capacity, 4);

      // Update Table 1 -> VIP-1 on 1st Floor with capacity 6
      final updated = initialTable.copyWith(
        name: 'VIP-1',
        floor: '1st Floor',
        capacity: 6,
      );
      await db.updateTable(updated);

      final found = db.tables.firstWhere((t) => t.id == initialTable.id);
      expect(found.name, 'VIP-1');
      expect(found.floor, '1st Floor');
      expect(found.capacity, 6);
    });

    test('isSameTable and normalizeTableIdentifier correctly isolates and matches tables', () {
      expect(isSameTable('Table 1', 'Table 1'), true);
      expect(isSameTable('Table 1', 'T-1'), true);
      expect(isSameTable('Table 1', 'T1'), true);
      expect(isSameTable('Table 01', '1'), true);
      expect(isSameTable('1', 'Table 1'), true);
      expect(isSameTable('Table 1', 'Table 2'), false);
      expect(isSameTable('Table 1', 'T-2'), false);
      expect(isSameTable('Table 1', 'Takeaway'), false);
      expect(isSameTable('Table 1', 'Delivery'), false);
      expect(isSameTable('A1', 'B1'), false);
      expect(isSameTable('VIP 1', 'Table 1'), false);
      expect(isSameTable('VIP 1', 'VIP 1'), true);
      expect(isSameTable('VIP 1', 'VIP 2'), false);
    });

    test('Moving table to floor re-sequences tables and saves changes', () async {
      final table2 = db.tables.firstWhere((t) => t.name == 'Table 2' || t.name == 'T-2');
      await db.moveTableToFloor(table2.id, 'Rooftop Lounge');

      final found = db.tables.firstWhere((t) => t.id == table2.id);
      expect(found.floor, 'Rooftop Lounge');
      expect(db.allFloors.contains('Rooftop Lounge'), true);
    });
  });
}

