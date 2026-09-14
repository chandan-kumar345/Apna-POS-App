import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Category Reordering and Sorting Tests', () async {
    final db = DatabaseService();
    await db.init();

    final user = UserModel(
      id: 'test_user_sort_1',
      name: 'Owner',
      email: 'owner@apnapos.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_1',
    );
    await db.saveActiveUser(user);

    // Add categories
    await db.addCategory('Desserts');
    await db.addCategory('Beverages');
    await db.addCategory('Starters');
    await db.addCategory('Main Course');

    expect(db.categories, ['Desserts', 'Beverages', 'Starters', 'Main Course']);

    // Reorder: Move 'Main Course' (index 3) to index 0
    await db.reorderCategories(3, 0);
    expect(db.categories, ['Main Course', 'Desserts', 'Beverages', 'Starters']);

    // Reorder: Move 'Desserts' (index 1) to index 3 (after Starters)
    await db.reorderCategories(1, 4);
    expect(db.categories, ['Main Course', 'Beverages', 'Starters', 'Desserts']);

    // Sort Alphabetical A -> Z
    await db.sortCategories('name_asc');
    expect(db.categories, ['Beverages', 'Desserts', 'Main Course', 'Starters']);

    // Sort Alphabetical Z -> A
    await db.sortCategories('name_desc');
    expect(db.categories, ['Starters', 'Main Course', 'Desserts', 'Beverages']);
  });

  test('In-Category Product Reordering and Sorting Tests', () async {
    final db = DatabaseService();
    await db.init();

    final user = UserModel(
      id: 'test_user_sort_2',
      name: 'Owner',
      email: 'owner2@apnapos.com',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_2',
    );
    await db.saveActiveUser(user);

    await db.addCategory('Beverages');

    final tea = MenuItemModel(
      id: 'bev_1',
      name: 'Chai Tea',
      category: 'Beverages',
      price: 20.0,
      description: 'Hot spiced chai',
      stockQuantity: 100,
      isAvailable: true,
    );
    final coffee = MenuItemModel(
      id: 'bev_2',
      name: 'Cold Coffee',
      category: 'Beverages',
      price: 60.0,
      description: 'Chilled coffee shake',
      stockQuantity: 40,
      isAvailable: true,
    );
    final lassi = MenuItemModel(
      id: 'bev_3',
      name: 'Sweet Lassi',
      category: 'Beverages',
      price: 50.0,
      description: 'Traditional Punjabi lassi',
      stockQuantity: 20,
      isAvailable: false,
    );

    // Also add a product in another category to ensure isolation
    final burger = MenuItemModel(
      id: 'food_1',
      name: 'Veg Burger',
      category: 'Fast Food',
      price: 99.0,
      description: 'Crispy burger',
    );

    await db.saveMenuItem(tea);
    await db.saveMenuItem(coffee);
    await db.saveMenuItem(lassi);
    await db.saveMenuItem(burger);

    // Initial order of Beverages: Chai Tea, Cold Coffee, Sweet Lassi
    var bevProducts = db.menuItems.where((m) => m.category == 'Beverages').toList();
    expect(bevProducts.map((p) => p.name).toList(), ['Chai Tea', 'Cold Coffee', 'Sweet Lassi']);

    // Reorder: Move Sweet Lassi (index 2) to top (index 0)
    await db.reorderCategoryProducts('Beverages', 2, 0);
    bevProducts = db.menuItems.where((m) => m.category == 'Beverages').toList();
    expect(bevProducts.map((p) => p.name).toList(), ['Sweet Lassi', 'Chai Tea', 'Cold Coffee']);

    // Fast Food product should still be intact
    expect(db.menuItems.any((m) => m.name == 'Veg Burger'), isTrue);

    // Sort Products by Price Low to High
    await db.sortCategoryProducts('Beverages', 'price_asc');
    bevProducts = db.menuItems.where((m) => m.category == 'Beverages').toList();
    expect(bevProducts.map((p) => p.name).toList(), ['Chai Tea', 'Sweet Lassi', 'Cold Coffee']);

    // Sort Products by Stock High to Low
    await db.sortCategoryProducts('Beverages', 'stock_desc');
    bevProducts = db.menuItems.where((m) => m.category == 'Beverages').toList();
    expect(bevProducts.map((p) => p.name).toList(), ['Chai Tea', 'Cold Coffee', 'Sweet Lassi']);

    // Sort Products Available First
    await db.sortCategoryProducts('Beverages', 'available_first');
    bevProducts = db.menuItems.where((m) => m.category == 'Beverages').toList();
    expect(bevProducts.last.name, 'Sweet Lassi'); // Lassi is false, so it must be last
  });
}
