import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/inventory_model.dart';
import 'user_database_helper.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SharedPreferences? _prefs;

  // In-Memory state for instant sync access
  UserModel? currentUser;
  List<UserModel> registeredUsers = [];
  RestaurantModel? restaurant;
  List<MenuItemModel> menuItems = [];
  List<String> categories = [];
  List<TableModel> tables = [];
  List<OrderModel> orders = [];
  List<InventoryItemModel> inventoryItems = [];
  final List<OrderModel> _holdOrders = [];
  List<OrderModel> get holdOrders => List.unmodifiable(_holdOrders);

  // Live in-cart totals per table (before KOT is sent)
  final Map<String, double> _liveCartTotals = {};
  final Map<String, List<CartItemModel>> _liveTableCarts = {};

  double getLiveCartTotal(String tableName) => _liveCartTotals[tableName] ?? 0.0;
  void setLiveCartTotal(String tableName, double total) {
    if (total <= 0) {
      _liveCartTotals.remove(tableName);
    } else {
      _liveCartTotals[tableName] = total;
    }
    notifyListeners();
  }

  List<CartItemModel> getLiveTableCart(String tableName) => List.from(_liveTableCarts[tableName] ?? []);
  void setLiveTableCart(String tableName, List<CartItemModel> items) {
    if (items.isEmpty) {
      _liveTableCarts.remove(tableName);
    } else {
      _liveTableCarts[tableName] = items.map((i) => CartItemModel(item: i.item, quantity: i.quantity, note: i.note)).toList();
    }
    notifyListeners();
  }

  void holdOrder(OrderModel order) {
    _holdOrders.add(order);
    notifyListeners();
  }

  OrderModel? unholdOrder(String orderId) {
    final idx = _holdOrders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      final removed = _holdOrders.removeAt(idx);
      notifyListeners();
      return removed;
    }
    return null;
  }

  TableModel? getNextAvailableTableSequence() {
    final freeList = tables.where((t) => t.status == TableStatus.free).toList();
    if (freeList.isEmpty) return null;
    freeList.sort((a, b) {
      final numA = int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      final numB = int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      return numA.compareTo(numB);
    });
    return freeList.first;
  }

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
        address: '',
        cuisineType: 'Indian & Continental',
        currencySymbol: '₹',
        taxRate: 5.0,
        tableCount: 12,
        isOnboarded: false,
      );
    }

    // 3. Load Menu Items
    final menuJson = _prefs?.getString('apna_pos_menu');
    if (menuJson != null) {
      final List raw = jsonDecode(menuJson);
      menuItems = raw.map((e) => MenuItemModel.fromJson(e)).toList();
    } else {
      menuItems = [];
    }

    final catJson = _prefs?.getString('apna_pos_categories');
    if (catJson != null) {
      final List raw = jsonDecode(catJson);
      categories = raw.map((e) => e.toString()).toList();
    } else {
      _syncCategoriesFromMenu();
    }

    // 4. Load Tables or Seed Clean Floor
    final tablesJson = _prefs?.getString('apna_pos_tables');
    if (tablesJson != null) {
      final List raw = jsonDecode(tablesJson);
      tables = raw.map((e) {
        final t = TableModel.fromJson(e);
        if (t.name.startsWith('Table ')) {
          return TableModel(
            id: t.id,
            tableNumber: t.tableNumber,
            name: 'T-${t.tableNumber}',
            floor: t.floor,
            capacity: t.capacity,
            status: t.status,
            currentOrderId: t.currentOrderId,
            occupiedSince: t.occupiedSince,
          );
        }
        return t;
      }).toList();
    } else {
      _seedCleanTables(restaurant?.tableCount ?? 12);
    }

    // 5. Load Orders
    final ordersJson = _prefs?.getString('apna_pos_orders');
    if (ordersJson != null) {
      final List raw = jsonDecode(ordersJson);
      orders = raw.map((e) => OrderModel.fromJson(e)).toList();
    } else {
      orders = [];
    }

    // 6. Load Inventory
    final inventoryJson = _prefs?.getString('apna_pos_inventory');
    if (inventoryJson != null) {
      final List raw = jsonDecode(inventoryJson);
      inventoryItems = raw.map((e) => InventoryItemModel.fromJson(e)).toList();
    } else {
      inventoryItems = [];
    }

    // 7. Load Registered Users List & Seed Default Testing Credential
    final dbHelper = UserDatabaseHelper();
    final sqliteUsers = await dbHelper.getAllUsers();
    
    if (sqliteUsers.isNotEmpty) {
      registeredUsers = sqliteUsers;
    } else {
      final regUsersJson = _prefs?.getString('apna_pos_registered_users');
      if (regUsersJson != null) {
        final List raw = jsonDecode(regUsersJson);
        registeredUsers = raw.map((e) => UserModel.fromJson(e)).toList();
      } else {
        registeredUsers = [];
      }
    }

    // Pre-seed default testing credential if missing: admin@apnapos.com / 9876543210 (pass: admin123)
    final hasAdmin = registeredUsers.any((u) => u.email.trim().toLowerCase() == 'admin@apnapos.com' || (u.phone != null && u.phone == '9876543210'));
    if (!hasAdmin) {
      registeredUsers.add(
        UserModel(
          id: 'usr_demo_admin',
          name: 'Demo Admin',
          email: 'admin@apnapos.com',
          phone: '9876543210',
          role: 'Owner',
          pin: '1234',
          restaurantId: restaurant?.id ?? 'rest_001',
          companyName: 'Apna POS Diner',
        ),
      );
      _saveRegisteredUsers();
    }

    notifyListeners();
  }

  Future<void> _saveRegisteredUsers() async {
    final raw = registeredUsers.map((u) => u.toJson()).toList();
    await _prefs?.setString('apna_pos_registered_users', jsonEncode(raw));
    
    // Sync with SQLite Database
    final dbHelper = UserDatabaseHelper();
    for (var user in registeredUsers) {
      await dbHelper.insertUser(user);
    }
  }

  // --- AUTHENTICATION SERVICES ---
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String pin,
    String? phone,
  }) async {
    final newId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = UserModel(
      id: newId,
      name: name,
      email: email,
      phone: phone,
      role: 'Owner',
      pin: pin,
      restaurantId: restaurant?.id ?? 'rest_001',
    );

    registeredUsers.removeWhere((u) => u.email.trim().toLowerCase() == email.trim().toLowerCase());
    registeredUsers.add(newUser);
    await _saveRegisteredUsers();

    currentUser = newUser;
    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
    notifyListeners();
    return true;
  }

  Future<bool> updateUserProfile({
    required String name,
    required String phone,
    required String jobTitle,
    required String companyName,
    String? website,
    String? referralCode,
    String? profilePhotoPath,
    Map<String, bool>? communicationPreferences,
  }) async {
    if (currentUser == null) {
      currentUser = UserModel(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: 'owner@apnapos.com',
        role: 'Owner',
        pin: '1234',
        restaurantId: restaurant?.id ?? 'rest_001',
      );
    }

    currentUser = currentUser!.copyWith(
      name: name,
      phone: phone,
      jobTitle: jobTitle,
      companyName: companyName,
      website: website,
      referralCode: referralCode,
      profilePhotoPath: profilePhotoPath,
      communicationPreferences: communicationPreferences,
    );

    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
    notifyListeners();
    return true;
  }

  Future<bool> updateBusinessName(String newCompanyName) async {
    final cleanName = newCompanyName.trim();
    if (cleanName.isEmpty) return false;

    if (currentUser != null) {
      currentUser = currentUser!.copyWith(companyName: cleanName);
      await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
    }

    if (restaurant != null) {
      restaurant = restaurant!.copyWith(name: cleanName);
      await _prefs?.setString('apna_pos_restaurant', jsonEncode(restaurant!.toJson()));
    } else {
      restaurant = RestaurantModel(
        id: 'rest_001',
        name: cleanName,
        tagline: 'Authentic Flavors & Swift Service',
        phone: '+91 98765 43210',
        address: '',
        cuisineType: 'Indian & Multi-Cuisine',
        currencySymbol: '₹',
        taxRate: 5.0,
        tableCount: 12,
        isOnboarded: true,
      );
      await _prefs?.setString('apna_pos_restaurant', jsonEncode(restaurant!.toJson()));
    }

    notifyListeners();
    return true;
  }

  Future<bool> loginUser(String identifier, String password) async {
    final cleanId = identifier.trim().toLowerCase();
    final cleanPw = password.trim();
    final digitsOnlyId = cleanId.replaceAll(RegExp(r'[^0-9]'), '');

    // 1. First search SQLite Database
    final dbHelper = UserDatabaseHelper();
    final sqliteUsers = await dbHelper.getAllUsers();
    
    UserModel? matched = sqliteUsers.where((u) {
      final uEmail = u.email.trim().toLowerCase();
      final uPhone = (u.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');

      bool idMatches = (uEmail == cleanId) ||
                       (digitsOnlyId.isNotEmpty && uPhone.endsWith(digitsOnlyId)) ||
                       (uPhone.isNotEmpty && uPhone == digitsOnlyId);
      return idMatches;
    }).firstOrNull;

    // 2. Search registeredUsers in memory if not found in SQLite
    matched ??= registeredUsers.where((u) {
      final uEmail = u.email.trim().toLowerCase();
      final uPhone = (u.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');

      bool idMatches = (uEmail == cleanId) ||
                       (digitsOnlyId.isNotEmpty && uPhone.endsWith(digitsOnlyId)) ||
                       (uPhone.isNotEmpty && uPhone == digitsOnlyId);
      return idMatches;
    }).firstOrNull;

    // 3. Check pre-seeded test accounts fallback
    if (matched == null) {
      if (cleanId == 'admin@apnapos.com' || cleanId == '9876543210' || cleanId == 'owner@apnapos.com' || cleanId == 'admin@restaurant.com' || cleanId == 'staff@apnapos.com') {
        matched = UserModel(
          id: 'usr_demo_admin',
          name: cleanId == 'owner@apnapos.com' ? 'Apna POS Owner' : (cleanId == 'admin@restaurant.com' ? 'Restaurant Manager' : (cleanId == 'staff@apnapos.com' ? 'Staff Account' : 'Demo Admin')),
          email: cleanId.contains('@') ? cleanId : 'admin@apnapos.com',
          phone: cleanId.contains('@') ? '9876543210' : cleanId,
          role: 'Owner',
          pin: '1234',
          restaurantId: restaurant?.id ?? 'rest_001',
        );
        if (!registeredUsers.any((u) => u.email == matched!.email)) {
          registeredUsers.add(matched);
          _saveRegisteredUsers();
        }
      }
    }

    if (matched != null) {
      currentUser = matched;
      await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> loginWithGoogle(String email, String name, String? photoUrl) async {
    final cleanEmail = email.trim().toLowerCase();
    UserModel? matched = registeredUsers.where((u) => u.email.trim().toLowerCase() == cleanEmail).firstOrNull;

    if (matched == null) {
      matched = UserModel(
        id: 'usr_g_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        role: 'Owner',
        pin: '1234',
        restaurantId: restaurant?.id ?? 'rest_001',
        profilePhotoPath: photoUrl,
      );
      registeredUsers.add(matched);
      await _saveRegisteredUsers();
    }

    currentUser = matched;
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
    
    // Clear demo data for clean production launch if not manually set
    if (_prefs?.getString('apna_pos_menu') == null) {
      menuItems = [];
      await _saveMenuToPrefs();
    }
    if (_prefs?.getString('apna_pos_orders') == null) {
      orders = [];
      await _saveOrdersToPrefs();
    }
    if (_prefs?.getString('apna_pos_inventory') == null) {
      inventoryItems = [];
      await _saveInventoryToPrefs();
    }

    _seedCleanTables(restaurant!.tableCount);
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
      final isFree = status == TableStatus.free;
      if (isFree) {
        final tblName = tables[index].name;
        _liveCartTotals.remove(tblName);
        _liveTableCarts.remove(tblName);
        _liveCartTotals.remove('T-${tables[index].tableNumber}');
        _liveTableCarts.remove('T-${tables[index].tableNumber}');
      }
      final nowStr = status == TableStatus.occupied ? DateTime.now().toString().substring(11, 16) : null;
      tables[index] = TableModel(
        id: tables[index].id,
        tableNumber: tables[index].tableNumber,
        name: tables[index].name,
        floor: tables[index].floor,
        capacity: tables[index].capacity,
        status: status,
        currentOrderId: isFree ? null : (orderId ?? tables[index].currentOrderId),
        occupiedSince: isFree ? null : (nowStr ?? tables[index].occupiedSince),
      );
      await _saveTablesToPrefs();
      notifyListeners();
    }
  }

  Future<void> addTable(String name, String floor, int capacity) async {
    final nextNum = tables.isEmpty ? 1 : (tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1);
    final newT = TableModel(
      id: 'TBL-${DateTime.now().millisecondsSinceEpoch}',
      tableNumber: nextNum,
      name: name.trim().isEmpty ? 'T-$nextNum' : name.trim(),
      floor: floor.trim().isEmpty ? 'Ground Floor' : floor.trim(),
      capacity: capacity > 0 ? capacity : 4,
      status: TableStatus.free,
    );
    tables.add(newT);
    await _saveTablesToPrefs();
    notifyListeners();
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
    String? deliveryAddress,
    OrderStatus? status,
    String? customerName,
    String? customerPhone,
  }) async {
    final subtotal = items.fold(0.0, (sum, i) => sum + i.totalPrice);
    final taxRate = restaurant?.taxRate ?? 5.0;
    final taxAmount = (subtotal - discountAmount) * (taxRate / 100.0);
    final totalAmount = (subtotal - discountAmount) + taxAmount;

    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    String tSuffix = 'TK';
    if (tableNumber != null && tableNumber.isNotEmpty) {
      final cleanNum = tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
      tSuffix = cleanNum.isNotEmpty ? 'T$cleanNum' : tableNumber;
    }
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final orderNum = '$year$month$day-$hour$min-$tSuffix';

    final newOrder = OrderModel(
      id: orderId,
      orderNumber: orderNum,
      tableNumber: tableNumber,
      orderType: orderType,
      status: status ?? OrderStatus.pending,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
      createdAt: DateTime.now().toString().substring(11, 16),
      customerName: customerName,
      customerPhone: customerPhone,
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

      // If completed or cancelled, clear occupied table and live cart data
      if (newStatus == OrderStatus.completed || newStatus == OrderStatus.cancelled) {
        final tNum = orders[index].tableNumber;
        if (tNum != null && tNum.isNotEmpty) {
          _liveCartTotals.remove(tNum);
          _liveTableCarts.remove(tNum);

          final tIndex = tables.indexWhere((t) =>
            t.name.trim().toLowerCase() == tNum.trim().toLowerCase() ||
            t.tableNumber.toString() == tNum ||
            'T-${t.tableNumber}'.toLowerCase() == tNum.trim().toLowerCase()
          );
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
      address: '',
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
  void _seedCleanTables(int count) {
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
        status: TableStatus.free,
        occupiedSince: null,
      );
    });
    _saveTablesToPrefs();
  }

  void seedDemoTestingData() {
    _seedDefaultMenu();
    _seedDefaultTables(12);
    _seedSampleOrders();
    _seedDefaultInventory();
    notifyListeners();
  }

  void _seedDefaultMenu() {
    menuItems = [
      MenuItemModel(id: 'm1', name: 'Paneer Butter Masala', category: 'Main Course', price: 290.0, description: 'Cottage cheese cubes in rich tomato gravy', emoji: '🥘', imageUrl: 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=400&q=80', stockQuantity: 40),
      MenuItemModel(id: 'm2', name: 'Dal Makhani', category: 'Main Course', price: 240.0, description: 'Slow cooked black lentils with cream & butter', emoji: '🍲', imageUrl: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=400&q=80', stockQuantity: 55),
      MenuItemModel(id: 'm3', name: 'Butter Naan', category: 'Breads', price: 50.0, description: 'Traditional clay oven flatbread brushed with butter', emoji: '🫓', imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=400&q=80', stockQuantity: 120),
      MenuItemModel(id: 'm4', name: 'Special Chicken Biryani', category: 'Biryani & Rice', price: 340.0, description: 'Aromatic basmati rice cooked with spices & chicken', emoji: '🍚', imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=400&q=80', stockQuantity: 30),
      MenuItemModel(id: 'm5', name: 'Crispy Cheese Burger', category: 'Fast Food', price: 180.0, description: 'Loaded double veg patty burger with melted cheddar', emoji: '🍔', imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80', stockQuantity: 25),
      MenuItemModel(id: 'm6', name: 'Peri Peri Fries', category: 'Fast Food', price: 130.0, description: 'Crispy golden fries tossed in spicy peri peri mix', emoji: '🍟', imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=400&q=80', stockQuantity: 60),
      MenuItemModel(id: 'm7', name: 'Cold Coffee with Ice Cream', category: 'Beverages', price: 140.0, description: 'Chilled espresso blended with thick milk & vanilla scoop', emoji: '🥤', imageUrl: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=400&q=80', stockQuantity: 45),
      MenuItemModel(id: 'm8', name: 'Mango Lassi', category: 'Beverages', price: 110.0, description: 'Thick sweet yogurt drink infused with Alphonso mango', emoji: '🥭', imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=400&q=80', stockQuantity: 50),
      MenuItemModel(id: 'm9', name: 'Sizzling Brownie', category: 'Desserts', price: 220.0, description: 'Hot chocolate brownie topped with ice cream & fudge', emoji: '🍨', imageUrl: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=400&q=80', stockQuantity: 20),
      MenuItemModel(id: 'm10', name: 'Gulab Jamun (2 pcs)', category: 'Desserts', price: 90.0, description: 'Warm fried milk dumplings in cardamom syrup', emoji: '🍡', imageUrl: 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=400&q=80', stockQuantity: 65),
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
        name: 'T-$num',
        floor: floor,
        capacity: cap,
        status: (num == 2 || num == 5) ? TableStatus.occupied : (num == 7 ? TableStatus.runningKot : TableStatus.free),
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
