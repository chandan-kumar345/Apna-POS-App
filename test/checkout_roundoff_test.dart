import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/features/pos/payment_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('OrderModel roundOff serialization and copyWith', () {
    final item = MenuItemModel(
      id: 'item_1',
      name: 'Paneer Tikka',
      category: 'Starters',
      price: 199.50,
      description: 'Spicy cottage cheese',
    );

    final order = OrderModel(
      id: 'ORD-123',
      orderNumber: '20260822-001',
      items: [CartItemModel(item: item, quantity: 1)],
      subtotal: 199.50,
      taxAmount: 9.98,
      discountAmount: 0.0,
      roundOff: 0.52,
      totalAmount: 210.00,
      paymentMethod: 'Cash',
      createdAt: '12:30',
    );

    expect(order.roundOff, 0.52);
    expect(order.totalAmount, 210.00);

    final json = order.toJson();
    expect(json['roundOff'], 0.52);
    expect(json['totalAmount'], 210.00);

    final fromJson = OrderModel.fromJson(json);
    expect(fromJson.roundOff, 0.52);
    expect(fromJson.totalAmount, 210.00);

    final copied = order.copyWith(roundOff: -0.48, totalAmount: 209.00);
    expect(copied.roundOff, -0.48);
    expect(copied.totalAmount, 209.00);
  });

  test('KOT creation does NOT increase completed orders count', () async {
    final db = DatabaseService();
    await db.init();

    final user = UserModel(
      id: 'test_user_kot',
      name: 'KOT Test Owner',
      email: 'kot@example.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_kot',
    );
    await db.saveActiveUser(user);
    await db.clearUserDataForNewAccount();

    final burger = MenuItemModel(
      id: 'item_burger',
      name: 'Veg Burger',
      category: 'Burgers',
      price: 100.0,
      description: 'Fresh Burger',
    );
    await db.saveMenuItem(burger);

    // Initial state: 0 orders
    expect(db.orders.length, 0);

    // 1. User prints KOT ticket (Status: preparing, payment: 'KOT Pending')
    final kotOrder = await db.createOrder(
      items: [CartItemModel(item: burger, quantity: 2)],
      orderType: OrderType.dineIn,
      discountAmount: 0.0,
      paymentMethod: 'KOT Pending',
      status: OrderStatus.preparing,
      tableNumber: 'T-1',
    );

    expect(db.orders.length, 1);
    expect(kotOrder.status, OrderStatus.preparing);

    // Filtered completed sales count MUST be 0
    final completedOrders = db.orders.where((o) =>
      o.status == OrderStatus.completed &&
      !o.paymentMethod.toLowerCase().contains('kot')
    ).toList();
    expect(completedOrders.length, 0);

    // 2. User settles the bill via Cash with Round Off
    final double rawAmount = kotOrder.totalAmount;
    final double roundedTotal = rawAmount.roundToDouble();
    final double roundOff = roundedTotal - rawAmount;

    await db.completeOrderPayment(
      kotOrder.id,
      'Cash (Rec: ₹210)',
      roundOff: roundOff,
      totalAmount: roundedTotal,
    );

    // Completed sales count is now 1
    final settledOrders = db.orders.where((o) =>
      o.status == OrderStatus.completed &&
      !o.paymentMethod.toLowerCase().contains('kot')
    ).toList();
    expect(settledOrders.length, 1);
    expect(settledOrders.first.totalAmount, roundedTotal);
  });

  test('PaymentModalResult model holds round-off and payment details', () {
    final result = PaymentModalResult(
      paymentMethod: 'UPI (Ref: UPI-98765)',
      roundOff: 0.40,
      totalAmount: 155.00,
      cashTendered: null,
    );

    expect(result.paymentMethod, contains('UPI'));
    expect(result.roundOff, 0.40);
    expect(result.totalAmount, 155.00);
  });

  test('DatabaseService importProductsFromCsv properly creates and categorizes products', () async {
    final db = DatabaseService();
    await db.init();

    final user = UserModel(
      id: 'test_user_csv_import',
      name: 'CSV Test Owner',
      email: 'csv@apnapos.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_csv_bistro',
    );
    await db.saveActiveUser(user);

    final item1 = MenuItemModel(
      id: 'PRD-CSV-001',
      productId: 'PRD-CSV-001',
      name: 'Paneer Butter Masala',
      category: 'Main Course',
      price: 280.0,
      description: 'Rich gravy',
      itemType: 'Veg',
      variants: [
        ProductVariant(name: 'Half', price: 150.0),
        ProductVariant(name: 'Full', price: 280.0),
      ],
    );

    final item2 = MenuItemModel(
      id: 'PRD-CSV-002',
      productId: 'PRD-CSV-002',
      name: 'Cold Coffee',
      category: 'Beverages',
      price: 120.0,
      description: 'Brewed coffee with ice cream',
      itemType: 'Beverage',
    );

    final count = await db.importProductsFromCsv([item1, item2]);
    expect(count, 2);

    expect(db.menuItems.any((i) => i.name == 'Paneer Butter Masala'), isTrue);
    expect(db.menuItems.any((i) => i.name == 'Cold Coffee'), isTrue);
    expect(db.categories.contains('Main Course'), isTrue);
    expect(db.categories.contains('Beverages'), isTrue);

    final importedPaneer = db.menuItems.firstWhere((i) => i.name == 'Paneer Butter Masala');
    expect(importedPaneer.variants.length, 2);
    expect(importedPaneer.variants[0].name, 'Half');
    expect(importedPaneer.variants[0].price, 150.0);
  });
}
