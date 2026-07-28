import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/inventory_model.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SharedPreferences? _prefs;

  // In-Memory state for instant sync access
  UserModel? currentUser;
  RestaurantModel? restaurant;
  List<MenuItemModel> menuItems = [];
  List<String> categories = [];
  List<TableModel> tables = [];
  List<OrderModel> orders = [];
  List<InventoryItemModel> inventoryItems = [];

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize DB and load or seed data
  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    // 1. Load User Session
    final userJson = _prefs?.getString('apna_pos_user');
    if (userJson != null) {
      currentUser = UserModel.fromJson(jsonDecode(userJson));
    }

    // 2. Load Restaurant Profile
    final restaurantJson = _prefs?.getString('apna_pos_restaurant');
    if (restaurantJson != null) {
      restaurant = RestaurantModel.fromJson(jsonDecode(restaurantJson));
    } else {
      // Default initial restaurant
      restaurant = RestaurantModel(
        id: 'rest_001',
        name: 'Apna POS Diner',
        tagline: 'Authentic Flavors & Swift Service',
        phone: '+91 98765 43210',
        address: '12-A Connaught Place, New Delhi',
        cuisineType: 'Indian & Continental',
        currencySymbol: '₹',
        taxRate: 5.0,
        tableCount: 12,
        isOnboarded: false,
      );
    }

    // 3. Load Menu Items or Seed
    final menuJson = _prefs?.getString('apna_pos_menu');
    if (menuJson != null) {
      final List raw = jsonDecode(menuJson);
      menuItems = raw.map((e) => MenuItemModel.fromJson(e)).toList();
    } else {
      _seedDefaultMenu();
    }

    final catJson = _prefs?.getString('apna_pos_categories');
    if (catJson != null) {
      final List raw = jsonDecode(catJson);
      categories = raw.map((e) => e.toString()).toList();
    } else {
      _syncCategoriesFromMenu();
    }

    // 4. Load Tables or Seed
    final tablesJson = _prefs?.getString('apna_pos_tables');
    if (tablesJson != null) {
      final List raw = jsonDecode(tablesJson);
      tables = raw.map((e) => TableModel.fromJson(e)).toList();
    } else {
      _seedDefaultTables(restaurant?.tableCount ?? 12);
    }

    // 5. Load Orders
    final ordersJson = _prefs?.getString('apna_pos_orders');
    if (ordersJson != null) {
      final List raw = jsonDecode(ordersJson);
      orders = raw.map((e) => OrderModel.fromJson(e)).toList();
    } else {
      _seedSampleOrders();
    }

    // 6. Load Inventory or Seed
    final inventoryJson = _prefs?.getString('apna_pos_inventory');
    if (inventoryJson != null) {
      final List raw = jsonDecode(inventoryJson);
      inventoryItems = raw.map((e) => InventoryItemModel.fromJson(e)).toList();
    } else {
      _seedDefaultInventory();
    }

    _isInitialized = true;
    notifyListeners();
  }

  // --- AUTHENTICATION SERVICES ---
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String pin,
  }) async {
    final newId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    currentUser = UserModel(
      id: newId,
      name: name,
      email: email,
      role: 'Owner',
      pin: pin,
      restaurantId: restaurant?.id ?? 'rest_001',
    );
    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
    notifyListeners();
    return true;
  }

  Future<bool> loginUser(String email, String password) async {
    // Demo authentication accepting credentials or default owner
    if (currentUser != null && currentUser!.email == email) {
      await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
      notifyListeners();
      return true;
    }
    // Auto-create user for frictionless login testing
    currentUser = UserModel(
      id: 'usr_owner_01',
      name: email.split('@').first.toUpperCase(),
      email: email,
      role: 'Owner',
      pin: '1234',
      restaurantId: restaurant?.id ?? 'rest_001',
    );
    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
    notifyListeners();
    return true;
  }

  Future<bool> loginWithPin(String pin) async {
    if (currentUser != null && currentUser!.pin == pin) {
      notifyListeners();
      return true;
    }
    // Default PIN check
    if (pin == '1234' || pin == '0000') {
      currentUser ??= UserModel(
        id: 'usr_staff_01',
        name: 'Manager Staff',
        email: 'manager@apnapos.com',
        role: 'Manager',
        pin: pin,
        restaurantId: restaurant?.id ?? 'rest_001',
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    currentUser = null;
    await _prefs?.remove('apna_pos_user');
    notifyListeners();
  }

  // --- RESTAURANT ONBOARDING SERVICES ---
  Future<void> saveRestaurantOnboarding(RestaurantModel updated) async {
    restaurant = updated.copyWith(isOnboarded: true);
    await _prefs?.setString('apna_pos_restaurant', jsonEncode(restaurant!.toJson()));
    _seedDefaultTables(restaurant!.tableCount);
    notifyListeners();
  }

  Future<void> updateRestaurantProfile(RestaurantModel updated) async {
    restaurant = updated;
    await _prefs?.setString('apna_pos_restaurant', jsonEncode(restaurant!.toJson()));
    notifyListeners();
  }

  // --- MENU MANAGEMENT SERVICES ---
  Future<void> saveMenuItem(MenuItemModel item) async {
    final index = menuItems.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      menuItems[index] = item;
    } else {
      menuItems.add(item);
    }
    await _saveMenuToPrefs();
    notifyListeners();
  }

  Future<void> deleteMenuItem(String id) async {
    menuItems.removeWhere((item) => item.id == id);
    await _saveMenuToPrefs();
    notifyListeners();
  }

  Future<void> toggleMenuItemAvailability(String id) async {
    final index = menuItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      menuItems[index] = menuItems[index].copyWith(isAvailable: !menuItems[index].isAvailable);
      await _saveMenuToPrefs();
      notifyListeners();
    }
  }

  Future<void> _saveMenuToPrefs() async {
    await _prefs?.setString('apna_pos_menu', jsonEncode(menuItems.map((e) => e.toJson()).toList()));
    _syncCategoriesFromMenu();
  }

  // --- CATEGORY MANAGEMENT SERVICES ---
  Future<void> addCategory(String categoryName) async {
    final name = categoryName.trim();
    if (name.isNotEmpty && !categories.contains(name)) {
      categories.add(name);
      await _saveCategoriesToPrefs();
      notifyListeners();
    }
  }

  Future<void> editCategory(String oldName, String newName) async {
    final updatedName = newName.trim();
    if (updatedName.isEmpty || oldName == updatedName) return;

    final index = categories.indexOf(oldName);
    if (index >= 0) {
      categories[index] = updatedName;
      // Update all menu items in this category
      for (int i = 0; i < menuItems.length; i++) {
        if (menuItems[i].category == oldName) {
          menuItems[i] = menuItems[i].copyWith(category: updatedName);
        }
      }
      await _saveMenuToPrefs();
      await _saveCategoriesToPrefs();
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    categories.remove(categoryName);
    await _saveCategoriesToPrefs();
    notifyListeners();
  }

  void _syncCategoriesFromMenu() {
    for (var item in menuItems) {
      if (!categories.contains(item.category)) {
        categories.add(item.category);
      }
    }
    _saveCategoriesToPrefs();
  }

  Future<void> _saveCategoriesToPrefs() async {
    await _prefs?.setString('apna_pos_categories', jsonEncode(categories));
  }

  // --- TABLE MANAGEMENT SERVICES ---
  Future<void> updateTableStatus(String tableId, TableStatus status, {String? orderId}) async {
    final index = tables.indexWhere((t) => t.id == tableId);
    if (index >= 0) {
      final nowStr = status == TableStatus.occupied ? DateTime.now().toString().substring(11, 16) : null;
      tables[index] = tables[index].copyWith(
        status: status,
        currentOrderId: orderId,
        occupiedSince: nowStr,
      );
      await _saveTablesToPrefs();
      notifyListeners();
    }
  }

  Future<void> _saveTablesToPrefs() async {
    await _prefs?.setString('apna_pos_tables', jsonEncode(tables.map((e) => e.toJson()).toList()));
  }

  // --- ORDERS & POS BILLING SERVICES ---
  Future<OrderModel> createOrder({
    required List<CartItemModel> items,
    String? tableNumber,
    required OrderType orderType,
    required double discountAmount,
    required String paymentMethod,
  }) async {
    final subtotal = items.fold(0.0, (sum, i) => sum + i.totalPrice);
    final taxRate = restaurant?.taxRate ?? 5.0;
    final taxAmount = (subtotal - discountAmount) * (taxRate / 100.0);
    final totalAmount = (subtotal - discountAmount) + taxAmount;

    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final orderNum = '#${(orders.length + 101)}';

    final newOrder = OrderModel(
      id: orderId,
      orderNumber: orderNum,
      tableNumber: tableNumber,
      orderType: orderType,
      status: OrderStatus.pending,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now().toString().substring(11, 16),
    );

    orders.insert(0, newOrder);
    await _saveOrdersToPrefs();

    // If table assigned, mark table as Occupied or Billed
    if (tableNumber != null && tableNumber.isNotEmpty) {
      final tIndex = tables.indexWhere((t) => t.name == tableNumber || t.tableNumber.toString() == tableNumber);
      if (tIndex >= 0) {
        updateTableStatus(tables[tIndex].id, TableStatus.occupied, orderId: orderId);
      }
    }

    // Deduct stock quantity
    for (var cartItem in items) {
      final mIndex = menuItems.indexWhere((m) => m.id == cartItem.item.id);
      if (mIndex >= 0) {
        final currentQty = menuItems[mIndex].stockQuantity;
        final newQty = (currentQty - cartItem.quantity).clamp(0, 999);
        menuItems[mIndex] = menuItems[mIndex].copyWith(stockQuantity: newQty);
      }
    }
    _saveMenuToPrefs();

    notifyListeners();
    return newOrder;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      orders[index] = orders[index].copyWith(status: newStatus);

      // If completed or cancelled, clear occupied table
      if (newStatus == OrderStatus.completed || newStatus == OrderStatus.cancelled) {
        final tNum = orders[index].tableNumber;
        if (tNum != null) {
          final tIndex = tables.indexWhere((t) => t.name == tNum || t.tableNumber.toString() == tNum);
          if (tIndex >= 0) {
            updateTableStatus(tables[tIndex].id, TableStatus.free);
          }
        }
      }
      await _saveOrdersToPrefs();
      notifyListeners();
    }
  }

  Future<void> _saveOrdersToPrefs() async {
    await _prefs?.setString('apna_pos_orders', jsonEncode(orders.map((e) => e.toJson()).toList()));
  }

  // --- INVENTORY SERVICES ---
  Future<void> addInventoryStock(String id, double addedQty) async {
    final index = inventoryItems.indexWhere((inv) => inv.id == id);
    if (index >= 0) {
      final newQty = inventoryItems[index].quantity + addedQty;
      inventoryItems[index] = inventoryItems[index].copyWith(quantity: newQty);
      await _saveInventoryToPrefs();
      notifyListeners();
    }
  }

  Future<void> _saveInventoryToPrefs() async {
    await _prefs?.setString('apna_pos_inventory', jsonEncode(inventoryItems.map((e) => e.toJson()).toList()));
  }

  // --- RE-SEED & RESET DATABASE ---
  Future<void> resetDatabase() async {
    await _prefs?.clear();
    menuItems.clear();
    tables.clear();
    orders.clear();
    inventoryItems.clear();

    _seedDefaultMenu();
    _seedDefaultTables(12);
    _seedSampleOrders();
    _seedDefaultInventory();
    
    restaurant = RestaurantModel(
      id: 'rest_001',
      name: 'Apna POS Diner',
      tagline: 'Taste the Perfection',
      phone: '+91 98765 43210',
      address: '12-A Connaught Place, New Delhi',
      cuisineType: 'Indian & Multi-Cuisine',
      currencySymbol: '₹',
      taxRate: 5.0,
      tableCount: 12,
      isOnboarded: true,
    );
    await _prefs?.setString('apna_pos_restaurant', jsonEncode(restaurant!.toJson()));
    notifyListeners();
  }

  // SEEDERS
  void _seedDefaultMenu() {
    menuItems = [
      MenuItemModel(id: 'm1', name: 'Paneer Butter Masala', category: 'Main Course', price: 290.0, description: 'Cottage cheese cubes in rich tomato gravy', emoji: '🥘', stockQuantity: 40),
      MenuItemModel(id: 'm2', name: 'Dal Makhani', category: 'Main Course', price: 240.0, description: 'Slow cooked black lentils with cream & butter', emoji: '🍲', stockQuantity: 55),
      MenuItemModel(id: 'm3', name: 'Butter Naan', category: 'Breads', price: 50.0, description: 'Traditional clay oven flatbread brushed with butter', emoji: '🫓', stockQuantity: 120),
      MenuItemModel(id: 'm4', name: 'Special Chicken Biryani', category: 'Biryani & Rice', price: 340.0, description: 'Aromatic basmati rice cooked with spices & chicken', emoji: '🍚', stockQuantity: 30),
      MenuItemModel(id: 'm5', name: 'Crispy Cheese Burger', category: 'Fast Food', price: 180.0, description: 'Loaded double veg patty burger with melted cheddar', emoji: '🍔', stockQuantity: 25),
      MenuItemModel(id: 'm6', name: 'Peri Peri Fries', category: 'Fast Food', price: 130.0, description: 'Crispy golden fries tossed in spicy peri peri mix', emoji: '🍟', stockQuantity: 60),
      MenuItemModel(id: 'm7', name: 'Cold Coffee with Ice Cream', category: 'Beverages', price: 140.0, description: 'Chilled espresso blended with thick milk & vanilla scoop', emoji: '🥤', stockQuantity: 45),
      MenuItemModel(id: 'm8', name: 'Mango Lassi', category: 'Beverages', price: 110.0, description: 'Thick sweet yogurt drink infused with Alphonso mango', emoji: '🥭', stockQuantity: 50),
      MenuItemModel(id: 'm9', name: 'Sizzling Brownie', category: 'Desserts', price: 220.0, description: 'Hot chocolate brownie topped with ice cream & fudge', emoji: '🍨', stockQuantity: 20),
      MenuItemModel(id: 'm10', name: 'Gulab Jamun (2 pcs)', category: 'Desserts', price: 90.0, description: 'Warm fried milk dumplings in cardamom syrup', emoji: '🍡', stockQuantity: 65),
    ];
    _saveMenuToPrefs();
  }

  void _seedDefaultTables(int count) {
    tables = List.generate(count, (index) {
      final num = index + 1;
      final floor = num <= 8 ? 'Ground Floor' : 'Terrace Garden';
      final cap = (num % 3 == 0) ? 6 : (num % 2 == 0 ? 4 : 2);
      return TableModel(
        id: 'tbl_$num',
        tableNumber: num,
        name: 'Table $num',
        floor: floor,
        capacity: cap,
        status: (num == 2 || num == 5) ? TableStatus.occupied : (num == 7 ? TableStatus.billed : TableStatus.free),
        occupiedSince: (num == 2 || num == 5) ? '19:42' : null,
      );
    });
    _saveTablesToPrefs();
  }

  void _seedSampleOrders() {
    orders = [
      OrderModel(
        id: 'ORD-8821',
        orderNumber: '#101',
        tableNumber: 'Table 2',
        orderType: OrderType.dineIn,
        status: OrderStatus.preparing,
        items: [
          CartItemModel(item: menuItems[0], quantity: 2),
          CartItemModel(item: menuItems[2], quantity: 4),
        ],
        subtotal: 780.0,
        taxAmount: 39.0,
        totalAmount: 819.0,
        paymentMethod: 'UPI',
        createdAt: '19:42',
      ),
      OrderModel(
        id: 'ORD-8822',
        orderNumber: '#102',
        tableNumber: 'Table 5',
        orderType: OrderType.dineIn,
        status: OrderStatus.pending,
        items: [
          CartItemModel(item: menuItems[3], quantity: 1),
          CartItemModel(item: menuItems[7], quantity: 2),
        ],
        subtotal: 560.0,
        taxAmount: 28.0,
        totalAmount: 588.0,
        paymentMethod: 'Cash',
        createdAt: '19:50',
      ),
      OrderModel(
        id: 'ORD-8820',
        orderNumber: '#100',
        tableNumber: 'Takeaway',
        orderType: OrderType.takeaway,
        status: OrderStatus.completed,
        items: [
          CartItemModel(item: menuItems[4], quantity: 2),
          CartItemModel(item: menuItems[5], quantity: 1),
        ],
        subtotal: 490.0,
        taxAmount: 24.5,
        totalAmount: 514.5,
        paymentMethod: 'Card',
        createdAt: '19:15',
      ),
    ];
    _saveOrdersToPrefs();
  }

  void _seedDefaultInventory() {
    inventoryItems = [
      InventoryItemModel(id: 'inv_1', name: 'Basmati Rice', category: 'Grains', quantity: 45.0, unit: 'kg', minThreshold: 10.0, costPerUnit: 110.0),
      InventoryItemModel(id: 'inv_2', name: 'Fresh Paneer', category: 'Dairy', quantity: 3.5, unit: 'kg', minThreshold: 5.0, costPerUnit: 380.0),
      InventoryItemModel(id: 'inv_3', name: 'Amul Butter', category: 'Dairy', quantity: 12.0, unit: 'kg', minThreshold: 4.0, costPerUnit: 520.0),
      InventoryItemModel(id: 'inv_4', name: 'Coffee Beans', category: 'Beverage Raw', quantity: 8.0, unit: 'kg', minThreshold: 2.0, costPerUnit: 850.0),
      InventoryItemModel(id: 'inv_5', name: 'Cooking Oil', category: 'Essentials', quantity: 25.0, unit: 'L', minThreshold: 8.0, costPerUnit: 140.0),
      InventoryItemModel(id: 'inv_6', name: 'Takeaway Boxes', category: 'Packaging', quantity: 150.0, unit: 'pcs', minThreshold: 50.0, costPerUnit: 12.0),
    ];
    _saveInventoryToPrefs();
  }
}
