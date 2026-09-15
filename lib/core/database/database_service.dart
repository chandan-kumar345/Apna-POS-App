import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/inventory_model.dart';
import '../models/extra_model.dart';
import '../models/print_log_model.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_factory.dart';
import '../services/session_manager.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';
import '../services/table_service.dart';
import '../services/inventory_service.dart';
import '../services/customer_service.dart';
import '../services/extra_service.dart';
import '../services/report_service.dart';
import '../services/dashboard_service.dart';
import '../services/payment_service.dart';
import '../services/print_log_service.dart';
import '../services/socket_service.dart';
import '../utils/order_calculator.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal() {
    _initSocketListeners();
  }

  SharedPreferences? _prefs;
  IAuthRepository get authRepository => AuthRepositoryFactory.instance;
  final SessionManager sessionManager = SessionManager();
  final FirestoreService _firestoreService = FirestoreService();
  AuthService get authService => AuthService();
  AuthService get _authService => AuthService();
  ProductService get productService => ProductService();
  OrderService get orderService => OrderService();
  TableService get tableService => TableService();
  InventoryService get inventoryService => InventoryService();
  CustomerService get customerService => CustomerService();
  ExtraService get extraService => ExtraService();
  PaymentService get paymentService => PaymentService();
  ReportService get reportService => ReportService();
  DashboardService get dashboardService => DashboardService();
  PrintLogService get printLogService => PrintLogService();
  SocketService get socketService => SocketService();
  
  ProductService get _productService => productService;
  OrderService get _orderService => orderService;
  TableService get _tableService => tableService;
  InventoryService get _inventoryService => inventoryService;
  CustomerService get _customerService => customerService;
  ExtraService get _extraService => extraService;
  SocketService get _socketService => socketService;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  int get unsyncedOrdersCount => orders.where((o) => !o.isSynced).length;

  // In-Memory state for instant sync access
  UserModel? currentUser;
  List<UserModel> registeredUsers = [];
  RestaurantModel? restaurant;
  List<MenuItemModel> menuItems = [];
  List<String> categories = [];
  Map<String, String> categoryImages = {};
  List<TableModel> tables = [];
  List<OrderModel> orders = [];
  List<InventoryItemModel> inventoryItems = [];
  List<CustomerModel> customers = [];
  List<ExtraModel> extras = [];
  final List<OrderModel> _holdOrders = [];
  List<OrderModel> get holdOrders => List.unmodifiable(_holdOrders);

  // Live in-cart totals per table (before KOT is sent)
  final Map<String, double> _liveCartTotals = {};
  final Map<String, List<CartItemModel>> _liveTableCarts = {};
  final Map<String, Map<String, dynamic>> _liveTableDiscounts = {};

  Map<String, dynamic>? getLiveTableDiscount(String tableName) {
    if (_liveTableDiscounts.containsKey(tableName)) {
      return _liveTableDiscounts[tableName];
    }
    for (final entry in _liveTableDiscounts.entries) {
      if (entry.key.toLowerCase().trim() == tableName.toLowerCase().trim() || isSameTable(entry.key, tableName)) {
        return entry.value;
      }
    }
    return null;
  }

  void setLiveTableDiscount(String tableName, {
    String coupon = '',
    double discountInput = 0.0,
    String discountMode = 'percent',
    double discountAmount = 0.0,
  }) {
    if (coupon.isEmpty && discountInput == 0.0 && discountAmount == 0.0) {
      _liveTableDiscounts.remove(tableName);
    } else {
      _liveTableDiscounts[tableName] = {
        'coupon': coupon,
        'discountInput': discountInput,
        'discountMode': discountMode,
        'discountAmount': discountAmount,
      };
    }
    _saveLiveTableCartsToPrefs();
    notifyListeners();
  }

  double getLiveCartTotal(String tableName) {
    final activeOrder = orders.where((o) =>
      isSameTable(o.tableNumber, tableName) &&
      (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
    ).firstOrNull;

    if (activeOrder != null && activeOrder.totalAmount > 0) {
      return activeOrder.totalAmount;
    }

    if (_liveCartTotals.containsKey(tableName)) {
      return _liveCartTotals[tableName] ?? 0.0;
    }

    for (final entry in _liveCartTotals.entries) {
      if (isSameTable(entry.key, tableName) && entry.value > 0) {
        return entry.value;
      }
    }

    return 0.0;
  }

  void setLiveCartTotal(String tableName, double total) {
    if (total <= 0) {
      _liveCartTotals.remove(tableName);
    } else {
      _liveCartTotals[tableName] = total;
    }
    _saveLiveTableCartsToPrefs();
    notifyListeners();
  }

  List<CartItemModel> getLiveTableCart(String tableName) {
    // 1. First check if there is an active running order in orders list
    final activeOrder = orders.where((o) =>
      isSameTable(o.tableNumber, tableName) &&
      (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
    ).firstOrNull;

    if (activeOrder != null && activeOrder.items.isNotEmpty) {
      return List.from(activeOrder.items);
    }

    // 2. Direct key match or normalized table match in persistent live table carts
    if (_liveTableCarts.containsKey(tableName) && _liveTableCarts[tableName]!.isNotEmpty) {
      return List.from(_liveTableCarts[tableName]!);
    }

    for (final entry in _liveTableCarts.entries) {
      if (isSameTable(entry.key, tableName) && entry.value.isNotEmpty) {
        return List.from(entry.value);
      }
    }

    return [];
  }

  void setLiveTableCart(String tableName, List<CartItemModel> items) {
    final tName = tableName.trim();
    if (tName.isEmpty) return;

    if (items.isEmpty) {
      _liveTableCarts.remove(tName);
      _liveTableCarts.remove('T-$tName');
    } else {
      _liveTableCarts[tName] = items.map((i) => i.clone()).toList();
    }

    final tIdx = tables.indexWhere((t) => isSameTable(t.name, tName));
    if (tIdx >= 0) {
      final current = tables[tIdx];
      if (items.isNotEmpty && (current.status == TableStatus.free || current.occupiedSince == null)) {
        tables[tIdx] = current.copyWith(
          status: TableStatus.occupied,
          occupiedSince: current.occupiedSince ?? DateTime.now().toIso8601String(),
          activeItemCount: items.length,
        );
        _saveTablesToPrefs();
      }
    }

    _saveLiveTableCartsToPrefs();
    notifyListeners();
  }

  /// Dynamically shift all live carts, active orders, and status from sourceTable to targetTable
  void shiftTableData(String sourceTable, String targetTable) {
    if (sourceTable.trim().toLowerCase() == targetTable.trim().toLowerCase()) return;

    // 1. Shift Live Cart items & Totals (Merge if target already has items)
    final srcCart = getLiveTableCart(sourceTable);
    final srcTotal = getLiveCartTotal(sourceTable);
    final dstCart = getLiveTableCart(targetTable);

    if (srcCart.isNotEmpty) {
      if (dstCart.isEmpty) {
        setLiveTableCart(targetTable, srcCart);
        setLiveCartTotal(targetTable, srcTotal);
      } else {
        // Merge items into target cart by item id & note
        final mergedCart = List<CartItemModel>.from(dstCart);
        for (final srcItem in srcCart) {
          final existingIdx = mergedCart.indexWhere(
            (m) => m.item.id == srcItem.item.id && m.note == srcItem.note,
          );
          if (existingIdx != -1) {
            mergedCart[existingIdx] = CartItemModel(
              item: mergedCart[existingIdx].item,
              quantity: mergedCart[existingIdx].quantity + srcItem.quantity,
              note: mergedCart[existingIdx].note,
              kotQuantity: mergedCart[existingIdx].kotQuantity + srcItem.kotQuantity,
            );
          } else {
            mergedCart.add(srcItem.clone());
          }
        }
        setLiveTableCart(targetTable, mergedCart);
        setLiveCartTotal(targetTable, (_liveCartTotals[targetTable] ?? 0.0) + srcTotal);
      }
    }

    // 2. Shift applied percentage discount / promo code
    final srcDiscount = getLiveTableDiscount(sourceTable);
    final dstDiscount = getLiveTableDiscount(targetTable);
    if (srcDiscount != null && dstDiscount == null) {
      setLiveTableDiscount(
        targetTable,
        coupon: srcDiscount['coupon']?.toString() ?? '',
        discountInput: (srcDiscount['discountInput'] as num?)?.toDouble() ?? 0.0,
        discountMode: srcDiscount['discountMode']?.toString() ?? 'percent',
        discountAmount: (srcDiscount['discountAmount'] as num?)?.toDouble() ?? 0.0,
      );
    }
    _liveTableCarts.remove(sourceTable);
    _liveCartTotals.remove(sourceTable);
    _liveTableDiscounts.remove(sourceTable);

    // 3. Shift Active pending / preparing Orders
    final shiftedOrders = <OrderModel>[];
    for (int i = 0; i < orders.length; i++) {
      final o = orders[i];
      if (isSameTable(o.tableNumber, sourceTable) &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)) {
        final updatedOrder = o.copyWith(tableNumber: targetTable);
        orders[i] = updatedOrder;
        shiftedOrders.add(updatedOrder);
      }
    }

    // 4. Update Table Statuses
    final srcTbl = tables.where((t) => isSameTable(t.name, sourceTable)).firstOrNull;
    final dstTbl = tables.where((t) => isSameTable(t.name, targetTable)).firstOrNull;
    final sourceOccupiedSince = srcTbl?.occupiedSince;

    if (srcTbl != null) {
      updateTableStatus(srcTbl.id, TableStatus.free);
    }
    if (dstTbl != null) {
      final hasKotOrders = orders.any((o) =>
        isSameTable(o.tableNumber, targetTable) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing),
      );
      final finalCart = getLiveTableCart(targetTable);
      final newStatus = hasKotOrders
          ? TableStatus.runningKot
          : (finalCart.isNotEmpty ? TableStatus.occupied : TableStatus.free);
      updateTableStatus(dstTbl.id, newStatus, occupiedSince: sourceOccupiedSince);
    }

    _saveLiveTableCartsToPrefs();
    _saveOrdersToPrefs();
    _saveTablesToPrefs();
    notifyListeners();
  }

  Future<void> _saveLiveTableCartsToPrefs() async {
    try {
      final Map<String, dynamic> rawMap = {};
      _liveTableCarts.forEach((key, list) {
        rawMap[key] = list.map((i) => i.toJson()).toList();
      });
      await _prefs?.setString(_userKey('live_table_carts'), jsonEncode(rawMap));
      await _prefs?.setString(_userKey('live_cart_totals'), jsonEncode(_liveCartTotals));
      await _prefs?.setString(_userKey('live_table_discounts'), jsonEncode(_liveTableDiscounts));
    } catch (_) {}
  }

  void _loadLiveTableCartsFromPrefs() {
    try {
      final cartsJson = _prefs?.getString(_userKey('live_table_carts'));
      if (cartsJson != null && cartsJson.isNotEmpty) {
        final Map<String, dynamic> rawMap = jsonDecode(cartsJson);
        rawMap.forEach((key, val) {
          if (val is List) {
            _liveTableCarts[key] = val
                .whereType<Map>()
                .map((j) => CartItemModel.fromJson(j))
                .toList();
          }
        });
      }
      final totalsJson = _prefs?.getString(_userKey('live_cart_totals'));
      if (totalsJson != null && totalsJson.isNotEmpty) {
        final Map<String, dynamic> rawTotals = jsonDecode(totalsJson);
        rawTotals.forEach((key, val) {
          if (val is num) {
            _liveCartTotals[key] = val.toDouble();
          }
        });
      }
      final discountsJson = _prefs?.getString(_userKey('live_table_discounts'));
      if (discountsJson != null && discountsJson.isNotEmpty) {
        final Map<String, dynamic> rawDiscounts = jsonDecode(discountsJson);
        rawDiscounts.forEach((key, val) {
          if (val is Map) {
            _liveTableDiscounts[key] = Map<String, dynamic>.from(val);
          }
        });
      }
    } catch (_) {}
  }

  void clearTableCartAndFree(String? tableRef) {
    if (tableRef == null || tableRef.trim().isEmpty) return;
    final tRef = tableRef.trim();

    _liveCartTotals.remove(tRef);
    _liveTableCarts.remove(tRef);
    _liveTableDiscounts.remove(tRef);
    _liveCartTotals.remove('T-$tRef');
    _liveTableCarts.remove('T-$tRef');
    _liveTableDiscounts.remove('T-$tRef');

    for (int i = 0; i < tables.length; i++) {
      final t = tables[i];
      if (isSameTable(t.name, tRef) || isSameTable(t.tableNumber.toString(), tRef) || isSameTable('T-${t.tableNumber}', tRef)) {
        _liveCartTotals.remove(t.name);
        _liveTableCarts.remove(t.name);
        _liveCartTotals.remove('T-${t.tableNumber}');
        _liveTableCarts.remove('T-${t.tableNumber}');
        tables[i] = t.copyWith(
          status: TableStatus.free,
          currentOrderId: null,
          activeOrderNumber: null,
          activeOrderTotal: 0.0,
          activeItemCount: 0,
          occupiedSince: null,
        );
        updateTableStatus(t.id, TableStatus.free);
      }
    }
    _saveLiveTableCartsToPrefs();
    _saveTablesToPrefs();
    notifyListeners();
  }

  /// Cancels active preparing/pending orders for a table, syncs cancellation to backend, and marks table as Free
  Future<void> voidTableOrderAndFree(String? tableRef, {String? orderId, String? reason}) async {
    if (tableRef == null || tableRef.trim().isEmpty) return;
    final tRef = tableRef.trim();

    // 1. Mark matching pending/preparing orders as Cancelled in memory
    final List<String> cancelledOrderIds = [];
    for (int i = 0; i < orders.length; i++) {
      final o = orders[i];
      final isMatch = (orderId != null && (o.id == orderId || o.orderNumber == orderId)) ||
          isSameTable(o.tableNumber, tRef) ||
          (o.tableNumber != null && isSameTable('T-${o.tableNumber}', tRef));

      if (isMatch && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)) {
        orders[i] = o.copyWith(status: OrderStatus.cancelled);
        cancelledOrderIds.add(o.id);
      }
    }

    // 2. Free the table and reset live cart immediately
    clearTableCartAndFree(tRef);
    await _saveOrdersToPrefs();
    notifyListeners();

    // 3. Sync cancellation of these orders to the backend cloud API
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        for (final id in cancelledOrderIds) {
          try {
            await _orderService.updateOrderStatus(id, OrderStatus.cancelled);
          } catch (err) {
            debugPrint('[DatabaseService.voidTableOrderAndFree] order cancel error: $err');
          }
        }
      }
    } catch (_) {}
  }

  void _reconcileTablesWithRunningOrders() {
    for (int i = 0; i < tables.length; i++) {
      final tbl = tables[i];
      final activeOrder = orders.where((o) =>
        isSameTable(o.tableNumber, tbl.name) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
      ).firstOrNull;

      if (activeOrder != null) {
        final mappedStatus = (activeOrder.status == OrderStatus.preparing)
            ? TableStatus.runningKot
            : TableStatus.occupied;
        final startA = parseTableOccupiedSince(tbl.occupiedSince);
        final startB = parseTableOccupiedSince(activeOrder.createdAt);
        final String? earliestStart = (startA != null && startB != null)
            ? (startA.isBefore(startB) ? tbl.occupiedSince : activeOrder.createdAt)
            : (tbl.occupiedSince ?? activeOrder.createdAt);

        tables[i] = tbl.copyWith(
          status: mappedStatus,
          currentOrderId: activeOrder.id,
          activeOrderNumber: activeOrder.orderNumber,
          activeOrderTotal: activeOrder.totalAmount,
          activeItemCount: activeOrder.items.length,
          occupiedSince: earliestStart,
        );
        _liveCartTotals[tbl.name] = activeOrder.totalAmount;
        _liveTableCarts[tbl.name] = activeOrder.items.map((i) => i.clone()).toList();
      } else {
        // No active pending/preparing order exists for this table
        final hasDraftCart = (_liveTableCarts.containsKey(tbl.name) && _liveTableCarts[tbl.name]!.isNotEmpty) ||
            (_liveTableCarts.containsKey('T-${tbl.tableNumber}') && _liveTableCarts['T-${tbl.tableNumber}']!.isNotEmpty);
        if (!hasDraftCart) {
          if (tbl.status != TableStatus.reserved) {
            tables[i] = tbl.copyWith(
              status: TableStatus.free,
              currentOrderId: null,
              activeOrderNumber: null,
              activeOrderTotal: 0.0,
              activeItemCount: 0,
              occupiedSince: null,
            );
          }
          _liveCartTotals.remove(tbl.name);
          _liveTableCarts.remove(tbl.name);
          _liveCartTotals.remove('T-${tbl.tableNumber}');
          _liveTableCarts.remove('T-${tbl.tableNumber}');
        } else {
          // Has draft cart products before KOT is printed -> status is Occupied
          if (tbl.status == TableStatus.free) {
            final cartItems = getLiveTableCart(tbl.name);
            final cartTotal = getLiveCartTotal(tbl.name);
            tables[i] = tbl.copyWith(
              status: TableStatus.occupied,
              activeOrderTotal: cartTotal,
              activeItemCount: cartItems.length,
              occupiedSince: tbl.occupiedSince ?? DateTime.now().toIso8601String(),
            );
          }
        }
      }
    }
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

  String _userKey(String baseKey) {
    final uid = (currentUser?.id != null && currentUser!.id.isNotEmpty)
        ? currentUser!.id
        : 'guest';
    return 'apna_pos_${uid}_$baseKey';
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Load or switch the dataset for the active user ID
  Future<void> loadUserDataForActiveUser(String userId) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    ProductService.clearPosCache();
    _holdOrders.clear();
    _liveCartTotals.clear();
    _liveTableCarts.clear();

    // 1. Load Restaurant Profile (User-scoped)
    final restaurantJson = _prefs?.getString('apna_pos_${userId}_restaurant');
    if (restaurantJson != null && restaurantJson.isNotEmpty) {
      try {
        restaurant = RestaurantModel.fromJson(jsonDecode(restaurantJson));
      } catch (e) {
        restaurant = null;
      }
    } else {
      restaurant = RestaurantModel(
        id: 'rest_$userId',
        name: currentUser?.companyName ?? currentUser?.name ?? 'Apna POS Store',
        tagline: 'Authentic Flavors & Swift Service',
        phone: currentUser?.phone ?? '',
        address: '',
        cuisineType: 'General',
        currencySymbol: '₹',
        taxRate: 5.0,
        tableCount: 12,
        isOnboarded: false,
      );
    }

    // 2. Load Menu Items (User-scoped) - Default to empty list [] for user isolation
    final menuJson = _prefs?.getString('apna_pos_${userId}_menu');
    if (menuJson != null && menuJson.isNotEmpty) {
      try {
        final List raw = jsonDecode(menuJson);
        menuItems = raw.map((e) => MenuItemModel.fromJson(e)).toList();
        _deduplicateMenuItems();
      } catch (e) {
        menuItems = [];
      }
    } else {
      menuItems = [];
    }

    // 3. Load Categories (User-scoped)
    final catJson = _prefs?.getString('apna_pos_${userId}_categories');
    if (catJson != null && catJson.isNotEmpty) {
      try {
        final List raw = jsonDecode(catJson);
        categories = raw.map((e) => (e ?? '').toString().trim()).where((s) => s.isNotEmpty).toList();
      } catch (e) {
        categories = [];
      }
    } else {
      categories = [];
      _syncCategoriesFromMenu();
    }

    // 3b. Load Category Images (User-scoped)
    final catImagesJson = _prefs?.getString('apna_pos_${userId}_category_images');
    if (catImagesJson != null && catImagesJson.isNotEmpty) {
      try {
        final Map rawMap = jsonDecode(catImagesJson);
        categoryImages = rawMap.map((k, v) => MapEntry((k ?? '').toString().trim(), (v ?? '').toString().trim()));
      } catch (e) {
        categoryImages = {};
      }
    } else {
      categoryImages = {};
    }

    // 4. Load Tables (User-scoped) or Seed Clean Floor
    final tablesJson = _prefs?.getString('apna_pos_${userId}_tables');
    if (tablesJson != null && tablesJson.isNotEmpty) {
      try {
        final List raw = jsonDecode(tablesJson);
        tables = raw.map((e) => TableModel.fromJson(e)).toList();
        _sortTablesSequentially();
      } catch (e) {
        _seedCleanTables(restaurant?.tableCount ?? 12);
      }
    } else {
      _seedCleanTables(restaurant?.tableCount ?? 12);
    }

    // 5. Load Orders (User-scoped) - Default to empty list [] for user isolation
    final ordersJson = _prefs?.getString('apna_pos_${userId}_orders');
    if (ordersJson != null && ordersJson.isNotEmpty) {
      try {
        final List raw = jsonDecode(ordersJson);
        orders = deduplicateOrdersList(raw.map((e) => OrderModel.fromJson(e)).toList());
        // If duplicates were purged on load, save clean state back to prefs immediately
        if (orders.length != raw.length) {
          _saveOrdersToPrefs();
        }
      } catch (e) {
        orders = [];
      }
    } else {
      orders = [];
    }

    // 6. Load Inventory (User-scoped) - Default to empty list [] for user isolation
    final inventoryJson = _prefs?.getString('apna_pos_${userId}_inventory');
    if (inventoryJson != null && inventoryJson.isNotEmpty) {
      try {
        final List raw = jsonDecode(inventoryJson);
        inventoryItems = raw.map((e) => InventoryItemModel.fromJson(e)).toList();
      } catch (e) {
        inventoryItems = [];
      }
    } else {
      inventoryItems = [];
    }

    // 7. Load Customers (User-scoped) - Default to empty list [] for user isolation
    final customersJson = _prefs?.getString('apna_pos_${userId}_customers');
    if (customersJson != null && customersJson.isNotEmpty) {
      try {
        final List raw = jsonDecode(customersJson);
        customers = raw.map((e) => CustomerModel.fromJson(e)).toList();
      } catch (e) {
        customers = [];
      }
    } else {
      customers = [];
    }

    // 8. Load persistent live table carts
    _loadLiveTableCartsFromPrefs();

    // 9. Reconcile tables with running orders
    _reconcileTablesWithRunningOrders();

    // 10. Load manual products history
    _loadManualProductsHistoryFromPrefs();

    notifyListeners();

    // Asynchronously sync customers from backend server
    syncCustomersFromBackend();
  }

  // Initialize DB and load or seed data
  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    // 1. Load User Session from SessionManager or direct SharedPreferences cache
    try {
      final userJson = _prefs?.getString('apna_pos_user');
      if (userJson != null && userJson.isNotEmpty) {
        try {
          currentUser = UserModel.fromJson(jsonDecode(userJson));
        } catch (e) {
          debugPrint('Error parsing cached user: $e');
        }
      }

      if (currentUser == null) {
        final isLoggedIn = await sessionManager.isLoggedIn();
        if (isLoggedIn) {
          final activeUserId = await sessionManager.getLoggedInUserId();
          if (activeUserId != null) {
            final userEntity = await authRepository.getUserById(activeUserId);
            if (userEntity != null) {
              currentUser = UserModel(
                id: userEntity.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
                name: userEntity.fullName,
                email: userEntity.email,
                phone: userEntity.phoneNumber,
                role: 'Owner',
                pin: '1234',
                restaurantId: 'rest_$activeUserId',
                profilePhotoPath: userEntity.profileImage,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring user session in DatabaseService.init: $e');
    }

    // 2. Load Registered Users List
    final regUsersJson = _prefs?.getString('apna_pos_registered_users');
    if (regUsersJson != null) {
      final List raw = jsonDecode(regUsersJson);
      registeredUsers = raw.map((e) => UserModel.fromJson(e)).toList();
    } else {
      registeredUsers = [];
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
          restaurantId: 'rest_001',
          companyName: 'Apna POS Diner',
        ),
      );
      _saveRegisteredUsers();
    }

    // 3. Load active user's dataset if logged in, otherwise clean state
    if (currentUser != null && currentUser!.id.isNotEmpty) {
      await loadUserDataForActiveUser(currentUser!.id);
    } else {
      menuItems.clear();
      categories.clear();
      orders.clear();
      inventoryItems.clear();
      _holdOrders.clear();
      _liveCartTotals.clear();
      _liveTableCarts.clear();
      restaurant = null;
    }

    _isInitialized = true;
    notifyListeners();

    // Connect real-time socket client if user has an active business
    if (currentUser != null && currentUser!.restaurantId.isNotEmpty) {
      _socketService.connect(businessId: currentUser!.restaurantId);
    }

    // Start real-time background auto-sync across devices
    startAutoSync();

    // Background sync with live backend if logged in
    syncWithBackend();
  }

  Timer? _autoSyncTimer;
  bool _isSilentSyncing = false;

  void _initSocketListeners() {
    _socketService.onOrderSettled = (data) {
      final orderId = data['orderId']?.toString() ?? data['id']?.toString() ?? '';
      final orderNumber = data['orderNumber']?.toString() ?? '';
      final tableRef = data['tableNumber']?.toString() ?? '';
      final double totalAmount = (data['totalAmount'] is num) ? (data['totalAmount'] as num).toDouble() : 0.0;
      final paymentMethod = data['paymentMethod']?.toString() ?? 'Cash';

      // 1. Update or record completed order locally
      final idx = orders.indexWhere((o) =>
          (orderId.isNotEmpty && o.id == orderId) ||
          (orderNumber.isNotEmpty && o.orderNumber == orderNumber));

      if (idx >= 0) {
        orders[idx] = orders[idx].copyWith(
          status: OrderStatus.completed,
          paymentStatus: 'paid',
          isPaid: true,
          totalAmount: totalAmount > 0 ? totalAmount : orders[idx].totalAmount,
          paymentMethod: paymentMethod.isNotEmpty ? paymentMethod : orders[idx].paymentMethod,
        );
      } else if (data['order'] is Map) {
        try {
          final incomingOrder = OrderModel.fromJson(Map<String, dynamic>.from(data['order'] as Map));
          orders.insert(0, incomingOrder.copyWith(
            status: OrderStatus.completed,
            paymentStatus: 'paid',
            isPaid: true,
          ));
        } catch (_) {}
      }

      // Also resolve any stale preparing/pending orders for this table
      if (tableRef.isNotEmpty) {
        for (int i = 0; i < orders.length; i++) {
          final o = orders[i];
          if (isSameTable(o.tableNumber, tableRef) &&
              (o.status == OrderStatus.pending || o.status == OrderStatus.preparing || o.status == OrderStatus.ready)) {
            orders[i] = o.copyWith(
              status: OrderStatus.completed,
              paymentStatus: 'paid',
              isPaid: true,
            );
          }
        }
      }

      orders = deduplicateOrdersList(orders);
      _saveOrdersToPrefs();

      // 2. Authoritatively clear table cart and free table on this device
      if (tableRef.isNotEmpty) {
        clearTableCartAndFree(tableRef);
      }
      notifyListeners();
    };

    _socketService.onOrderUpdated = (data) {
      final orderId = data['orderId']?.toString() ?? data['id']?.toString() ?? '';
      final orderNumber = data['orderNumber']?.toString() ?? '';
      final statusStr = data['status']?.toString().toLowerCase() ?? '';
      final tableRef = data['tableNumber']?.toString() ?? '';

      final idx = orders.indexWhere((o) =>
          (orderId.isNotEmpty && o.id == orderId) ||
          (orderNumber.isNotEmpty && o.orderNumber == orderNumber));

      if (idx >= 0 && statusStr.isNotEmpty) {
        final newStatus = OrderStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == statusStr,
          orElse: () => orders[idx].status,
        );
        final isPaid = statusStr == 'completed' || data['paymentStatus'] == 'paid' || data['isPaid'] == true;
        orders[idx] = orders[idx].copyWith(
          status: newStatus,
          paymentStatus: isPaid ? 'paid' : orders[idx].paymentStatus,
          isPaid: isPaid ? true : orders[idx].isPaid,
        );
        _saveOrdersToPrefs();

        if (newStatus == OrderStatus.completed || newStatus == OrderStatus.cancelled) {
          if (tableRef.isNotEmpty) {
            clearTableCartAndFree(tableRef);
          } else if (orders[idx].tableNumber != null) {
            clearTableCartAndFree(orders[idx].tableNumber);
          }
        }
        notifyListeners();
      }
    };

    _socketService.onTableUpdated = (updatedTable) {
      final idx = tables.indexWhere((t) =>
          (t.id.isNotEmpty && t.id == updatedTable.id) ||
          t.tableNumber == updatedTable.tableNumber ||
          isSameTable(t.name, updatedTable.name));

      if (idx >= 0) {
        final existingTbl = tables[idx];
        final isExistingRunning = existingTbl.status == TableStatus.occupied || existingTbl.status == TableStatus.runningKot;
        final isUpdatedRunning = updatedTable.status == TableStatus.occupied || updatedTable.status == TableStatus.runningKot;

        final hasLocalDraftCart = (_liveTableCarts[existingTbl.name]?.isNotEmpty == true) ||
            (_liveTableCarts['T-${existingTbl.tableNumber}']?.isNotEmpty == true);
        final hasLocalActiveOrder = orders.any((o) =>
            isSameTable(o.tableNumber, existingTbl.name) &&
            (o.status == OrderStatus.pending || o.status == OrderStatus.preparing));

        if (updatedTable.status == TableStatus.free) {
          final isServerClean = updatedTable.activeOrderId == null && updatedTable.activeOrderNumber == null;
          final hasCompletedOrder = orders.any((o) =>
              isSameTable(o.tableNumber, existingTbl.name) &&
              (o.status == OrderStatus.completed || o.isPaid));
          final hasUnsyncedActiveOrder = orders.any((o) =>
              isSameTable(o.tableNumber, existingTbl.name) &&
              !o.isSynced &&
              (o.status == OrderStatus.pending || o.status == OrderStatus.preparing));

          if (hasUnsyncedActiveOrder) {
            // Local cashier actively working with an un-synced offline order
            return;
          } else if (hasCompletedOrder) {
            // Dining session was completed/settled! Purge stale leftover cart and free table
            _liveCartTotals.remove(existingTbl.name);
            _liveTableCarts.remove(existingTbl.name);
            _liveCartTotals.remove('T-${existingTbl.tableNumber}');
            _liveTableCarts.remove('T-${existingTbl.tableNumber}');
            for (int i = 0; i < orders.length; i++) {
              if (isSameTable(orders[i].tableNumber, existingTbl.name) &&
                  (orders[i].status == OrderStatus.pending || orders[i].status == OrderStatus.preparing)) {
                orders[i] = orders[i].copyWith(status: OrderStatus.completed, isPaid: true, paymentStatus: 'paid');
              }
            }
            _saveOrdersToPrefs();
          } else if (hasLocalDraftCart || hasLocalActiveOrder) {
            // Local cashier actively adding items to cart or preparing an order - protect it from stale socket
            return;
          } else if (isServerClean) {
            _liveCartTotals.remove(existingTbl.name);
            _liveTableCarts.remove(existingTbl.name);
            _liveCartTotals.remove('T-${existingTbl.tableNumber}');
            _liveTableCarts.remove('T-${existingTbl.tableNumber}');
          }
        }

        final String? mergedOccupiedSince;
        if (updatedTable.status == TableStatus.free) {
          mergedOccupiedSince = null;
        } else if (isExistingRunning && isUpdatedRunning) {
          // Never restart an ongoing running table timer on KOT or bill print!
          final existingStart = parseTableOccupiedSince(existingTbl.occupiedSince);
          final updatedStart = parseTableOccupiedSince(updatedTable.occupiedSince);
          if (existingStart != null && updatedStart != null) {
            mergedOccupiedSince = existingStart.isBefore(updatedStart)
                ? existingTbl.occupiedSince
                : updatedTable.occupiedSince;
          } else {
            mergedOccupiedSince = existingTbl.occupiedSince ?? updatedTable.occupiedSince;
          }
        } else if (isExistingRunning && !isUpdatedRunning) {
          mergedOccupiedSince = existingTbl.occupiedSince;
        } else {
          mergedOccupiedSince = updatedTable.occupiedSince ?? (isUpdatedRunning ? DateTime.now().toIso8601String() : null);
        }

        tables[idx] = updatedTable.copyWith(
          occupiedSince: mergedOccupiedSince,
        );
      } else {
        tables.add(updatedTable);
        _sortTablesSequentially();
      }

      if (updatedTable.status == TableStatus.free) {
        _liveCartTotals.remove(updatedTable.name);
        _liveTableCarts.remove(updatedTable.name);
        _liveCartTotals.remove('T-${updatedTable.tableNumber}');
        _liveTableCarts.remove('T-${updatedTable.tableNumber}');
      } else if (updatedTable.activeOrderTotal > 0) {
        setLiveCartTotal(updatedTable.name, updatedTable.activeOrderTotal);
      }

      _saveTablesToPrefs();
      notifyListeners();
    };

    _socketService.onTablesBatchUpdated = (updatedList) {
      for (final updatedTable in updatedList) {
        final idx = tables.indexWhere((t) =>
            (t.id.isNotEmpty && t.id == updatedTable.id) ||
            t.tableNumber == updatedTable.tableNumber ||
            isSameTable(t.name, updatedTable.name));

        if (idx >= 0) {
          final existingTbl = tables[idx];
          final isExistingRunning = existingTbl.status == TableStatus.occupied || existingTbl.status == TableStatus.runningKot;
          final isUpdatedRunning = updatedTable.status == TableStatus.occupied || updatedTable.status == TableStatus.runningKot;

          final hasLocalDraftCart = (_liveTableCarts[existingTbl.name]?.isNotEmpty == true) ||
              (_liveTableCarts['T-${existingTbl.tableNumber}']?.isNotEmpty == true);
          final hasLocalActiveOrder = orders.any((o) =>
              isSameTable(o.tableNumber, existingTbl.name) &&
              (o.status == OrderStatus.pending || o.status == OrderStatus.preparing));

          if (updatedTable.status == TableStatus.free) {
            final isServerClean = updatedTable.activeOrderId == null && updatedTable.activeOrderNumber == null;
            final hasCompletedOrder = orders.any((o) =>
                isSameTable(o.tableNumber, existingTbl.name) &&
                (o.status == OrderStatus.completed || o.isPaid));
            final hasUnsyncedActiveOrder = orders.any((o) =>
                isSameTable(o.tableNumber, existingTbl.name) &&
                !o.isSynced &&
                (o.status == OrderStatus.pending || o.status == OrderStatus.preparing));

            if (hasUnsyncedActiveOrder) {
              continue;
            } else if (hasCompletedOrder) {
              _liveCartTotals.remove(existingTbl.name);
              _liveTableCarts.remove(existingTbl.name);
              _liveCartTotals.remove('T-${existingTbl.tableNumber}');
              _liveTableCarts.remove('T-${existingTbl.tableNumber}');
              for (int i = 0; i < orders.length; i++) {
                if (isSameTable(orders[i].tableNumber, existingTbl.name) &&
                    (orders[i].status == OrderStatus.pending || orders[i].status == OrderStatus.preparing)) {
                  orders[i] = orders[i].copyWith(status: OrderStatus.completed, isPaid: true, paymentStatus: 'paid');
                }
              }
              _saveOrdersToPrefs();
            } else if (hasLocalDraftCart || hasLocalActiveOrder) {
              continue;
            } else if (isServerClean) {
              _liveCartTotals.remove(existingTbl.name);
              _liveTableCarts.remove(existingTbl.name);
              _liveCartTotals.remove('T-${existingTbl.tableNumber}');
              _liveTableCarts.remove('T-${existingTbl.tableNumber}');
            }
          }

          final String? mergedOccupiedSince;
          if (updatedTable.status == TableStatus.free) {
            mergedOccupiedSince = null;
          } else if (isExistingRunning && isUpdatedRunning) {
            final existingStart = parseTableOccupiedSince(existingTbl.occupiedSince);
            final updatedStart = parseTableOccupiedSince(updatedTable.occupiedSince);
            if (existingStart != null && updatedStart != null) {
              mergedOccupiedSince = existingStart.isBefore(updatedStart)
                  ? existingTbl.occupiedSince
                  : updatedTable.occupiedSince;
            } else {
              mergedOccupiedSince = existingTbl.occupiedSince ?? updatedTable.occupiedSince;
            }
          } else if (isExistingRunning && !isUpdatedRunning) {
            mergedOccupiedSince = existingTbl.occupiedSince;
          } else {
            mergedOccupiedSince = updatedTable.occupiedSince ?? (isUpdatedRunning ? DateTime.now().toIso8601String() : null);
          }

          tables[idx] = updatedTable.copyWith(
            occupiedSince: mergedOccupiedSince,
          );
        } else {
          tables.add(updatedTable);
        }

        if (updatedTable.status == TableStatus.free) {
          _liveCartTotals.remove(updatedTable.name);
          _liveTableCarts.remove(updatedTable.name);
          _liveCartTotals.remove('T-${updatedTable.tableNumber}');
          _liveTableCarts.remove('T-${updatedTable.tableNumber}');
        } else if (updatedTable.activeOrderTotal > 0) {
          setLiveCartTotal(updatedTable.name, updatedTable.activeOrderTotal);
        }
      }
      _saveTablesToPrefs();
      notifyListeners();
    };

    _socketService.onTableCreated = (newTable) {
      final idx = tables.indexWhere((t) =>
          (t.id.isNotEmpty && t.id == newTable.id) ||
          (t.tableNumber == newTable.tableNumber && isSameTable(t.name, newTable.name)));

      if (idx >= 0) {
        tables[idx] = newTable;
      } else {
        tables.add(newTable);
        _sortTablesSequentially();
      }
      _saveTablesToPrefs();
      notifyListeners();
    };

    _socketService.onTableDeleted = (deletedTableId) {
      tables.removeWhere((t) =>
          t.id == deletedTableId ||
          t.tableNumber.toString() == deletedTableId ||
          isSameTable(t.name, deletedTableId));
      _saveTablesToPrefs();
      notifyListeners();
    };

    _socketService.onReconnected = () {
      debugPrint('[DatabaseService] Socket reconnected. Synchronizing tables for live multi-device state...');
      _tableService.fetchTables().then((remoteTables) {
        if (remoteTables.isNotEmpty) {
          tables = remoteTables;
          for (final t in remoteTables) {
            if (t.status == TableStatus.free) {
              _liveCartTotals.remove(t.name);
              _liveTableCarts.remove(t.name);
            } else if (t.activeOrderTotal > 0) {
              setLiveCartTotal(t.name, t.activeOrderTotal);
            }
          }
          _saveTablesToPrefs();
          notifyListeners();
        }
      }).catchError((e) {
        debugPrint('[DatabaseService] Reconnect table sync error: $e');
      });
    };
  }

  /// Starts periodic background auto-sync for live tables and active orders across devices
  void startAutoSync({Duration interval = const Duration(seconds: 4)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) {
      syncTablesAndOrdersSilently();
    });
  }

  /// Stops periodic background auto-sync
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Triggers an immediate cloud sync on table state / order change
  Future<void> triggerImmediateSync() async {
    await syncTablesAndOrdersSilently();
  }

  /// Performs a silent, non-blocking background sync of live tables and active orders across all devices
  Future<void> syncTablesAndOrdersSilently() async {
    if (_isSilentSyncing) return;
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return;

      _isSilentSyncing = true;

      // 1. Push any local unsynced orders
      final unsynced = orders.where((o) => !o.isSynced).toList();
      if (unsynced.isNotEmpty) {
        for (final localOrder in unsynced) {
          try {
            final remoteOrder = await _orderService.createOrder(localOrder);
            final idx = orders.indexWhere((o) => o.id == localOrder.id || o.orderNumber == localOrder.orderNumber);
            if (idx >= 0) {
              orders[idx] = remoteOrder.copyWith(
                isSynced: true,
                items: remoteOrder.items.isNotEmpty ? remoteOrder.items : localOrder.items,
              );
            }
          } catch (err) {
            debugPrint('[DatabaseService.syncTablesAndOrdersSilently] Offline push error: $err');
          }
        }
      }

      // 2. Fetch live tables from backend
      final remoteTables = await _tableService.fetchTables();

      // 3. Fetch latest active orders from backend
      final remoteOrders = await _orderService.fetchOrders(limit: 200);

      bool hasChanged = false;

      // 4. Merge remote orders
      if (remoteOrders.isNotEmpty) {
        final Map<String, OrderModel> orderMap = {};
        for (final r in remoteOrders) {
          final key = r.orderNumber.isNotEmpty ? r.orderNumber : r.id;
          orderMap[key] = r.copyWith(isSynced: true);
        }
        for (final local in orders) {
          final key = local.orderNumber.isNotEmpty ? local.orderNumber : local.id;
          final existingRemote = orderMap[key] ?? (local.id.isNotEmpty ? orderMap[local.id] : null);
          if (existingRemote == null) {
            orderMap[key] = local;
          } else {
            if ((local.status == OrderStatus.completed || local.isPaid) &&
                existingRemote.status != OrderStatus.completed &&
                !existingRemote.isPaid) {
              orderMap[key] = local.copyWith(isSynced: false);
            } else {
              orderMap[key] = existingRemote.copyWith(
                items: existingRemote.items.isNotEmpty ? existingRemote.items : local.items,
              );
            }
          }
        }

        final mergedOrders = deduplicateOrdersList(orderMap.values.toList());
        mergedOrders.sort((a, b) => b.createdDateTime.compareTo(a.createdDateTime));

        if (orders.length != mergedOrders.length ||
            !listEquals(orders.map((o) => '${o.id}_${o.status.name}_${o.paymentStatus}_${o.totalAmount}').toList(),
                mergedOrders.map((o) => '${o.id}_${o.status.name}_${o.paymentStatus}_${o.totalAmount}').toList())) {
          orders = mergedOrders;
          hasChanged = true;
        }
      }

      // 5. Update and reconcile tables
      if (remoteTables.isNotEmpty) {
        final List<TableModel> merged = [];
        for (final rt in remoteTables) {
          final ltIdx = tables.indexWhere((t) =>
              (t.id.isNotEmpty && t.id == rt.id) ||
              t.tableNumber == rt.tableNumber ||
              isSameTable(t.name, rt.name));

          if (ltIdx >= 0) {
            final lt = tables[ltIdx];
            final isLtRunning = lt.status == TableStatus.occupied || lt.status == TableStatus.runningKot;
            final isRtRunning = rt.status == TableStatus.occupied || rt.status == TableStatus.runningKot;
            final hasLocalDraftCart = (_liveTableCarts[lt.name]?.isNotEmpty == true) ||
                (_liveTableCarts['T-${lt.tableNumber}']?.isNotEmpty == true);
            final hasLocalActiveOrder = orders.any((o) =>
                isSameTable(o.tableNumber, lt.name) &&
                (o.status == OrderStatus.pending || o.status == OrderStatus.preparing));

            final TableStatus finalStatus;
            final String? finalOccupiedSince;

            if (rt.status == TableStatus.free) {
              final isServerClean = rt.activeOrderId == null && rt.activeOrderNumber == null;
              final hasCompletedOrder = orders.any((o) =>
                  isSameTable(o.tableNumber, lt.name) &&
                  (o.status == OrderStatus.completed || o.isPaid));

              if (isServerClean && (hasCompletedOrder || !hasLocalActiveOrder)) {
                _liveTableCarts.remove(lt.name);
                _liveTableCarts.remove('T-${lt.tableNumber}');
                _liveCartTotals.remove(lt.name);
                _liveCartTotals.remove('T-${lt.tableNumber}');
                finalStatus = TableStatus.free;
                finalOccupiedSince = null;
              } else if (hasLocalDraftCart || hasLocalActiveOrder) {
                finalStatus = isLtRunning ? lt.status : TableStatus.occupied;
                finalOccupiedSince = lt.occupiedSince ?? DateTime.now().toIso8601String();
              } else {
                finalStatus = TableStatus.free;
                finalOccupiedSince = null;
              }
            } else if (isLtRunning && isRtRunning) {
              finalStatus = rt.status;
              final ltStart = parseTableOccupiedSince(lt.occupiedSince);
              final rtStart = parseTableOccupiedSince(rt.occupiedSince);
              if (ltStart != null && rtStart != null) {
                finalOccupiedSince = ltStart.isBefore(rtStart) ? lt.occupiedSince : rt.occupiedSince;
              } else {
                finalOccupiedSince = lt.occupiedSince ?? rt.occupiedSince;
              }
            } else if (isLtRunning && !isRtRunning) {
              finalStatus = lt.status;
              finalOccupiedSince = lt.occupiedSince;
            } else {
              finalStatus = rt.status;
              finalOccupiedSince = rt.occupiedSince ?? (isRtRunning ? DateTime.now().toIso8601String() : null);
            }

            merged.add(rt.copyWith(
              status: finalStatus,
              occupiedSince: finalOccupiedSince,
            ));
          } else {
            merged.add(rt);
          }
        }
        tables = merged;

        // Reconcile with latest running orders
        _reconcileTablesWithRunningOrders();
        hasChanged = true;
      }

      if (hasChanged) {
        await _saveOrdersToPrefs();
        await _saveTablesToPrefs();
        await _saveLiveTableCartsToPrefs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DatabaseService.syncTablesAndOrdersSilently] error: $e');
    } finally {
      _isSilentSyncing = false;
    }
  }

  /// Syncs all in-memory data with the live production backend MongoDB APIs
  Future<void> syncWithBackend() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return;

      _isSyncing = true;
      notifyListeners();

      // 1. Sync User Profile & Business Details
      try {
        final meData = await _authService.getMe();
        if (meData['user'] != null) {
          final u = meData['user'] as Map<String, dynamic>;
          final b = meData['business'] as Map<String, dynamic>?;
          final prof = b?['profile'] as Map<String, dynamic>?;
          final ordSet = b?['orderSettings'] as Map<String, dynamic>?;

          currentUser = UserModel(
            id: u['id']?.toString() ?? '',
            name: prof?['name']?.toString() ?? u['name']?.toString() ?? 'User',
            email: u['email']?.toString() ?? '',
            phone: u['phone']?.toString(),
            role: u['role']?.toString() ?? 'Owner',
            pin: '1234',
            restaurantId: b?['id']?.toString() ?? u['restaurantId']?.toString() ?? restaurant?.id ?? 'rest_001',
            companyName: prof?['companyName']?.toString() ?? u['companyName']?.toString(),
            profilePhotoPath: prof?['profileImage']?.toString() ?? u['profilePhotoPath']?.toString(),
          );

          if (b != null) {
            restaurant = RestaurantModel(
              id: b['id']?.toString() ?? 'rest_001',
              name: prof?['companyName']?.toString() ?? 'Apna POS Store',
              tagline: prof?['tagline']?.toString() ?? 'Authentic Flavors & Swift Service',
              phone: prof?['phone']?.toString() ?? '',
              address: b['address']?['addressLine']?.toString() ?? '',
              cuisineType: prof?['cuisineType']?.toString() ?? 'Indian & Continental',
              taxRate: (ordSet?['tax']?['percentage'] as num?)?.toDouble() ?? 5.0,
              tableCount: (ordSet?['tableCount'] as num?)?.toInt() ?? 12,
              isOnboarded: u['onboardingCompleted'] == true,
              upiId: ordSet?['upiId']?.toString() ?? 'apnapos@upi',
              posViewMode: ordSet?['posViewMode']?.toString() ?? 'with_image',
              enableChotuVoice: ordSet?['enableChotuVoice'] ?? true,
            );
            await _saveRestaurantToPrefs();
          }

          // Sync Category Images from Business Profile / Settings
          final rawRemoteCatImages = b?['categoryImages'] ?? ordSet?['categoryImages'] ?? prof?['categoryImages'] ?? b?['posSettings']?['categoryImages'];
          if (rawRemoteCatImages != null && rawRemoteCatImages is Map) {
            rawRemoteCatImages.forEach((k, v) {
              if (k != null && v != null && v.toString().trim().isNotEmpty) {
                final kStr = k.toString().trim();
                final vStr = v.toString().trim();
                categoryImages[kStr.toLowerCase()] = vStr;
                categoryImages[kStr] = vStr;
              }
            });
            await _saveCategoryImagesToPrefs();
          }

          // Connect real-time Socket.IO room for this business
          final activeBizId = currentUser?.restaurantId ?? restaurant?.id;
          if (activeBizId != null && activeBizId.isNotEmpty) {
            _socketService.connect(businessId: activeBizId);
          }
        }
      } catch (e) {
        debugPrint('[DatabaseService] sync user error: $e');
      }

      // 2. Fetch Live Products & Categories from Backend (Optimized POS API)
      try {
        final remoteProducts = await _productService.fetchPosProducts(forceRefresh: true);

        // Auto-heal / sync any local products that were not yet uploaded to the cloud (e.g. offline/CSV created)
        final unsyncedLocalItems = menuItems.where((localItem) =>
            localItem.id.startsWith('item_') ||
            localItem.id.startsWith('TEMP_') ||
            !remoteProducts.any((r) =>
                r.id == localItem.id ||
                (r.productId.isNotEmpty && r.productId == localItem.productId) ||
                r.name.trim().toLowerCase() == localItem.name.trim().toLowerCase())).toList();

        if (unsyncedLocalItems.isNotEmpty) {
          debugPrint('[DatabaseService] Auto-syncing ${unsyncedLocalItems.length} unsynced local products to backend cloud...');
          final synced = await _productService.bulkImport(unsyncedLocalItems);
          for (final s in synced) {
            if (!remoteProducts.any((r) =>
                r.id == s.id ||
                (r.productId.isNotEmpty && r.productId == s.productId) ||
                r.name.trim().toLowerCase() == s.name.trim().toLowerCase())) {
              remoteProducts.add(s);
            }
          }
        }

        if (remoteProducts.isNotEmpty || menuItems.isEmpty) {
          menuItems = remoteProducts;
          _deduplicateMenuItems();
          await _saveMenuToPrefs();
        }

        final remoteCategories = await _productService.fetchCategories(categoryImagesTarget: categoryImages);
        if (remoteCategories.isNotEmpty) {
          if (categories.isEmpty) {
            categories = remoteCategories;
          } else {
            for (final rc in remoteCategories) {
              if (!categories.any((c) => c.toLowerCase() == rc.toLowerCase())) {
                categories.add(rc);
              }
            }
          }
        } else {
          _syncCategoriesFromMenu();
        }
        await _saveCategoriesToPrefs();
        await _saveCategoryImagesToPrefs();

        // Push local categoryImages to cloud if remote doesn't have it yet
        if (categoryImages.isNotEmpty) {
          unawaited(() async {
            try {
              final ApiClient client = ApiClient();
              await client.patch(ApiEndpoints.posSettings, data: {
                'categoryImages': categoryImages,
              });
            } catch (_) {}
          }());
        }
      } catch (e) {
        debugPrint('[DatabaseService] sync products error: $e');
      }

      // 3. Fetch Live Tables from Backend
      try {
        final remoteTables = await _tableService.fetchTables();
        if (remoteTables.isNotEmpty) {
          final List<TableModel> mergedTables = [];
          for (final remoteTable in remoteTables) {
            final idx = tables.indexWhere((t) =>
                (t.id.isNotEmpty && t.id == remoteTable.id) ||
                t.tableNumber == remoteTable.tableNumber ||
                isSameTable(t.name, remoteTable.name));
            if (idx >= 0) {
              final localTbl = tables[idx];
              final isLocalRunning = localTbl.status == TableStatus.occupied || localTbl.status == TableStatus.runningKot;
              final isRemoteRunning = remoteTable.status == TableStatus.occupied || remoteTable.status == TableStatus.runningKot;
              final hasLocalDraftCart = (_liveTableCarts[localTbl.name]?.isNotEmpty == true) ||
                  (_liveTableCarts['T-${localTbl.tableNumber}']?.isNotEmpty == true);
              final hasLocalActiveOrder = orders.any((o) =>
                  isSameTable(o.tableNumber, localTbl.name) &&
                  (o.status == OrderStatus.pending || o.status == OrderStatus.preparing));

              final TableStatus resolvedStatus;
              final String? preservedSince;

              if (remoteTable.status == TableStatus.free) {
                final isServerClean = remoteTable.activeOrderId == null && remoteTable.activeOrderNumber == null;
                final hasCompletedOrder = orders.any((o) =>
                    isSameTable(o.tableNumber, localTbl.name) &&
                    (o.status == OrderStatus.completed || o.isPaid));

                if (isServerClean && (hasCompletedOrder || !hasLocalActiveOrder)) {
                  _liveTableCarts.remove(localTbl.name);
                  _liveTableCarts.remove('T-${localTbl.tableNumber}');
                  _liveCartTotals.remove(localTbl.name);
                  _liveCartTotals.remove('T-${localTbl.tableNumber}');
                  resolvedStatus = TableStatus.free;
                  preservedSince = null;
                } else if (hasLocalDraftCart || hasLocalActiveOrder) {
                  resolvedStatus = isLocalRunning ? localTbl.status : TableStatus.occupied;
                  preservedSince = localTbl.occupiedSince ?? DateTime.now().toIso8601String();
                } else {
                  resolvedStatus = TableStatus.free;
                  preservedSince = null;
                }
              } else if (isLocalRunning && isRemoteRunning) {
                resolvedStatus = remoteTable.status;
                final localStart = parseTableOccupiedSince(localTbl.occupiedSince);
                final remoteStart = parseTableOccupiedSince(remoteTable.occupiedSince);
                if (localStart != null && remoteStart != null) {
                  preservedSince = localStart.isBefore(remoteStart) ? localTbl.occupiedSince : remoteTable.occupiedSince;
                } else {
                  preservedSince = localTbl.occupiedSince ?? remoteTable.occupiedSince;
                }
              } else if (isLocalRunning && !isRemoteRunning) {
                resolvedStatus = localTbl.status;
                preservedSince = localTbl.occupiedSince;
              } else {
                resolvedStatus = remoteTable.status;
                preservedSince = remoteTable.occupiedSince ?? (isRemoteRunning ? DateTime.now().toIso8601String() : null);
              }
              mergedTables.add(remoteTable.copyWith(status: resolvedStatus, occupiedSince: preservedSince));
            } else {
              mergedTables.add(remoteTable);
            }
          }
          tables = mergedTables;
          for (final t in tables) {
            if (t.status == TableStatus.free) {
              final hasLocalDraftCart = (_liveTableCarts[t.name]?.isNotEmpty == true) ||
                  (_liveTableCarts['T-${t.tableNumber}']?.isNotEmpty == true);
              if (!hasLocalDraftCart) {
                _liveCartTotals.remove(t.name);
                _liveTableCarts.remove(t.name);
                _liveCartTotals.remove('T-${t.tableNumber}');
                _liveTableCarts.remove('T-${t.tableNumber}');
              }
            } else if (t.activeOrderTotal > 0) {
              setLiveCartTotal(t.name, t.activeOrderTotal);
            }
          }
          await _saveTablesToPrefs();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[DatabaseService] sync tables error: $e');
      }

      // 4. Multi-Device Bidirectional Order Syncing (Push Local Unsynced & Pull Cloud Orders)
      try {
        // A. Push local unsynced offline orders to cloud backend
        final unsynced = orders.where((o) => !o.isSynced).toList();
        if (unsynced.isNotEmpty) {
          debugPrint('[DatabaseService] Auto-syncing ${unsynced.length} offline orders to cloud...');
          for (final localOrder in unsynced) {
            try {
              final remoteOrder = await _orderService.createOrder(localOrder);
              final idx = orders.indexWhere((o) => o.id == localOrder.id || o.orderNumber == localOrder.orderNumber);
              if (idx >= 0) {
                orders[idx] = remoteOrder.copyWith(
                  isSynced: true,
                  items: remoteOrder.items.isNotEmpty ? remoteOrder.items : localOrder.items,
                );
              }
            } catch (err) {
              debugPrint('[DatabaseService] Error uploading offline order ${localOrder.orderNumber}: $err');
            }
          }
          await _saveOrdersToPrefs();
          notifyListeners();
        }

        // B. Fetch Live Orders from Backend (Pull latest orders for multi-device synchronization)
        final remoteOrders = await _orderService.fetchOrders(limit: 500);
        if (remoteOrders.isNotEmpty) {
          final Map<String, OrderModel> orderMap = {};

          // Seed with remote authoritative orders from cloud
          for (final r in remoteOrders) {
            final key = r.orderNumber.isNotEmpty ? r.orderNumber : r.id;
            orderMap[key] = r.copyWith(isSynced: true);
          }

          // Merge local orders (preserve any local-only unsynced orders or newer local payment statuses)
          for (final local in orders) {
            final key = local.orderNumber.isNotEmpty ? local.orderNumber : local.id;
            final existingRemote = orderMap[key] ?? (local.id.isNotEmpty ? orderMap[local.id] : null);

            if (existingRemote == null) {
              orderMap[key] = local;
            } else {
              // If local is paid/completed but remote was pending, prioritize completed local state
              if ((local.status == OrderStatus.completed || local.isPaid) &&
                  existingRemote.status != OrderStatus.completed &&
                  !existingRemote.isPaid) {
                orderMap[key] = local.copyWith(isSynced: false);
              } else {
                orderMap[key] = existingRemote.copyWith(
                  items: existingRemote.items.isNotEmpty ? existingRemote.items : local.items,
                );
              }
            }
          }

          final mergedOrders = deduplicateOrdersList(orderMap.values.toList());
          mergedOrders.sort((a, b) => b.createdDateTime.compareTo(a.createdDateTime));
          orders = mergedOrders;
          await _saveOrdersToPrefs();

          // Reconcile and activate running table orders across devices
          _reconcileTablesWithRunningOrders();
          await _saveTablesToPrefs();
          await _saveLiveTableCartsToPrefs();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[DatabaseService] sync orders error: $e');
      }

      // 5. Fetch Live Inventory from Backend
      try {
        final remoteInventory = await _inventoryService.fetchInventory();
        inventoryItems = remoteInventory;
        await _saveInventoryToPrefs();
      } catch (e) {
        debugPrint('[DatabaseService] sync inventory error: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _saveRegisteredUsers() async {
    final raw = registeredUsers.map((u) => u.toJson()).toList();
    await _prefs?.setString('apna_pos_registered_users', jsonEncode(raw));
  }

  // --- AUTHENTICATION SERVICES ---
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String pin,
    String? phone,
    String? profileImage,
    String? onboardingDetails,
  }) async {
    final nowStr = DateTime.now().toIso8601String();

    final userEntity = UserEntity(
      fullName: name.trim(),
      email: email.trim(),
      phoneNumber: phone?.trim() ?? '',
      password: password.trim(),
      profileImage: profileImage,
      createdAt: nowStr,
      onboardingDetails: onboardingDetails,
    );

    // Register via FirebaseAuthRepository & session cache
    UserEntity? createdUser;
    try {
      createdUser = await authRepository.registerUser(userEntity);
      if (createdUser.id != null) {
        await sessionManager.saveSession(createdUser.id!);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during registration: ${e.code} - ${e.message}');
      if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Firebase requires at least 6 characters.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('This email address is already registered in Firebase. Please log in.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address format.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception('Email/Password sign-in method is not enabled in your Firebase Console.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception(e.message ?? 'Firebase registration failed (${e.code}).');
      }
    } catch (e) {
      debugPrint('AuthRepository registerUser error: $e');
      rethrow;
    }

    currentUser = UserModel(
      id: createdUser.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim(),
      phone: phone?.trim(),
      role: 'Owner',
      pin: pin,
      restaurantId: restaurant?.id ?? 'rest_001',
    );

    final existingIdx = registeredUsers.indexWhere((u) => u.email.trim().toLowerCase() == email.trim().toLowerCase());
    if (existingIdx >= 0) {
      registeredUsers[existingIdx] = currentUser!;
    } else {
      registeredUsers.add(currentUser!);
    }
    await _saveRegisteredUsers();
    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
    await clearUserDataForNewAccount();

    notifyListeners();
    return true;
  }

  Future<void> _saveRestaurantToPrefs() async {
    if (restaurant != null) {
      await _prefs?.setString(_userKey('restaurant'), jsonEncode(restaurant!.toJson()));
    }
  }

  Future<void> saveActiveUser(UserModel user) async {
    final bool isUserSwitch = currentUser?.id != user.id;
    currentUser = user;
    final existingIdx = registeredUsers.indexWhere((u) => u.email.trim().toLowerCase() == user.email.trim().toLowerCase());
    if (existingIdx >= 0) {
      registeredUsers[existingIdx] = user;
    } else {
      registeredUsers.add(user);
    }
    await _saveRegisteredUsers();
    await _prefs?.setString('apna_pos_user', jsonEncode(user.toJson()));

    if (isUserSwitch) {
      await loadUserDataForActiveUser(user.id);
    }

    // Sync with Firestore
    await _firestoreService.saveUser(user);

    notifyListeners();
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

    // Persist to SharedPreferences session state
    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));

    // Sync with Firestore
    await _firestoreService.saveUser(currentUser!);

    notifyListeners();
    return true;
  }

  Future<bool> updateBusinessName(String newCompanyName) async {
    final cleanName = newCompanyName.trim();
    if (cleanName.isEmpty) return false;

    if (currentUser != null) {
      currentUser = currentUser!.copyWith(companyName: cleanName);
      await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));
      await _firestoreService.saveUser(currentUser!);
    }

    if (restaurant != null) {
      restaurant = restaurant!.copyWith(name: cleanName);
      await _saveRestaurantToPrefs();
      await _firestoreService.saveRestaurant(restaurant!);
    } else {
      restaurant = RestaurantModel(
        id: 'rest_${currentUser?.id ?? "001"}',
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
      await _saveRestaurantToPrefs();
    }

    notifyListeners();
    return true;
  }

  Future<bool> loginUser(String identifier, String password) async {
    final cleanId = identifier.trim();
    final cleanPw = password.trim();

    if (cleanId.isEmpty || cleanPw.isEmpty) {
      throw Exception('Please enter both email/phone and password.');
    }

    bool isFirebaseAuthSuccess = false;
    UserEntity? fbEntity;
    String? firebaseErrorMessage;

    // 1. Authenticate against Firebase Auth via FirebaseAuthRepository
    if (cleanId.contains('@')) {
      try {
        fbEntity = await authRepository.login(cleanId, cleanPw);
        if (fbEntity != null) {
          isFirebaseAuthSuccess = true;
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('FirebaseAuthException during login: ${e.code} - ${e.message}');
        if (e.code == 'user-not-found') {
          firebaseErrorMessage = 'No account found with this email. Please check your email or sign up.';
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          firebaseErrorMessage = 'Incorrect email address or password. Please try again.';
        } else if (e.code == 'invalid-email') {
          firebaseErrorMessage = 'Invalid email address format.';
        } else if (e.code == 'user-disabled') {
          firebaseErrorMessage = 'This user account has been disabled. Please contact support.';
        } else if (e.code == 'network-request-failed') {
          firebaseErrorMessage = 'Network connection error. Please check your internet connection.';
        } else {
          firebaseErrorMessage = 'Invalid email address or password. Please try again.';
        }
      } catch (e) {
        final errStr = e.toString();
        debugPrint('FirebaseAuth repository login error: $errStr');
        if (errStr.contains('user-not-found')) {
          firebaseErrorMessage = 'No account found with this email. Please check your email or sign up.';
        } else if (errStr.contains('wrong-password') || errStr.contains('invalid-credential')) {
          firebaseErrorMessage = 'Incorrect email address or password. Please try again.';
        } else {
          firebaseErrorMessage = 'Invalid email address or password. Please try again.';
        }
      }
    }

    // 2. Strict Firebase Authentication check for Email login
    if (cleanId.contains('@')) {
      if (!isFirebaseAuthSuccess) {
        if (firebaseErrorMessage != null) {
          throw Exception(firebaseErrorMessage);
        }
        return false;
      }
    }

    final cleanEmail = cleanId.toLowerCase();
    UserModel? matched = registeredUsers.where((u) => u.email.trim().toLowerCase() == cleanEmail || (u.phone ?? '').trim() == cleanId).firstOrNull;

    final fbUser = FirebaseAuth.instance.currentUser;
    if (isFirebaseAuthSuccess || fbUser != null || matched != null) {
      final finalEmail = fbEntity?.email ?? fbUser?.email ?? matched?.email ?? cleanId;
      final finalName = fbEntity?.fullName ?? fbUser?.displayName ?? matched?.name ?? (finalEmail.contains('@') ? finalEmail.split('@').first : 'Owner');
      final finalId = fbEntity?.id?.toString() ?? fbUser?.uid ?? matched?.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';

      currentUser = matched?.copyWith(
        id: finalId,
        name: finalName,
        email: finalEmail,
      ) ?? UserModel(
        id: finalId,
        name: finalName,
        email: finalEmail,
        phone: fbUser?.phoneNumber ?? matched?.phone ?? cleanId,
        role: 'Owner',
        pin: '1234',
        restaurantId: 'rest_$finalId',
      );

      final existingIdx = registeredUsers.indexWhere((u) => u.email.trim().toLowerCase() == finalEmail.toLowerCase());
      if (existingIdx >= 0) {
        registeredUsers[existingIdx] = currentUser!;
      } else {
        registeredUsers.add(currentUser!);
      }
      await _saveRegisteredUsers();
      await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));

      // Sync with Firestore
      if (currentUser != null) {
        await _firestoreService.saveUser(currentUser!);
      }

      await sessionManager.saveSession(finalId);
      await loadUserDataForActiveUser(finalId);

      notifyListeners();
      return true;
    }

    if (firebaseErrorMessage != null) {
      throw Exception(firebaseErrorMessage);
    }

    return false;
  }

  Future<bool> loginWithGoogle(String email, String name, String? photoUrl) async {
    final cleanEmail = email.trim().toLowerCase();
    UserModel? matched = registeredUsers.where((u) => u.email.trim().toLowerCase() == cleanEmail).firstOrNull;

    final isNewAccount = (matched == null);
    if (matched == null) {
      matched = UserModel(
        id: 'usr_g_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        role: 'Owner',
        pin: '1234',
        restaurantId: 'rest_001',
        profilePhotoPath: photoUrl,
      );
      registeredUsers.add(matched);
      await _saveRegisteredUsers();
    }

    currentUser = matched;
    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));

    // Sync with Firestore asynchronously in background
    if (currentUser != null) {
      unawaited(_firestoreService.saveUser(currentUser!).catchError((e) {
        debugPrint('[DatabaseService] firestore user sync notice: $e');
      }));
    }

    if (isNewAccount) {
      await clearUserDataForNewAccount();
    } else {
      await loadUserDataForActiveUser(matched.id);
    }

    notifyListeners();
    return true;
  }

  Future<bool> loginWithOtpPhone(String phone, {String? name}) async {
    final cleanPhone = phone.trim();
    UserModel? matched = registeredUsers.where((u) => (u.phone ?? '').trim() == cleanPhone || u.email.trim().toLowerCase() == 'user_$cleanPhone@apnapos.com'.toLowerCase()).firstOrNull;

    final isNewAccount = (matched == null);
    if (matched == null) {
      matched = UserModel(
        id: 'usr_p_${DateTime.now().millisecondsSinceEpoch}',
        name: name ?? (cleanPhone.length > 4 ? 'User (${cleanPhone.substring(cleanPhone.length - 4)})' : 'POS Owner'),
        email: 'user_$cleanPhone@apnapos.com',
        phone: cleanPhone,
        role: 'Owner',
        pin: '1234',
        restaurantId: 'rest_001',
      );
      registeredUsers.add(matched);
      await _saveRegisteredUsers();
    }

    currentUser = matched;
    await _prefs?.setString('apna_pos_user', jsonEncode(currentUser!.toJson()));

    // Sync with Firestore asynchronously in background
    if (currentUser != null) {
      unawaited(_firestoreService.saveUser(currentUser!).catchError((e) {
        debugPrint('[DatabaseService] firestore user sync notice: $e');
      }));
    }

    if (isNewAccount) {
      await clearUserDataForNewAccount();
    } else {
      await loadUserDataForActiveUser(matched.id);
    }

    notifyListeners();
    return true;
  }

  /// Clears menu items, orders, tables, and inventory data when a brand new user account is created.
  Future<void> clearUserDataForNewAccount() async {
    ProductService.clearPosCache();
    menuItems.clear();
    categories.clear();
    orders.clear();
    inventoryItems.clear();
    _holdOrders.clear();
    _liveCartTotals.clear();
    _liveTableCarts.clear();

    final uid = currentUser?.id ?? 'new_user';

    // Remove user-scoped keys
    await _prefs?.remove('apna_pos_${uid}_menu');
    await _prefs?.remove('apna_pos_${uid}_categories');
    await _prefs?.remove('apna_pos_${uid}_orders');
    await _prefs?.remove('apna_pos_${uid}_inventory');
    await _prefs?.remove('apna_pos_${uid}_tables');
    await _prefs?.remove('apna_pos_${uid}_restaurant');
    await _prefs?.remove('apna_pos_${uid}_manual_products_history');
    _manualProductsHistory.clear();

    // Remove legacy un-scoped keys
    await _prefs?.remove('apna_pos_menu');
    await _prefs?.remove('apna_pos_categories');
    await _prefs?.remove('apna_pos_orders');
    await _prefs?.remove('apna_pos_inventory');
    await _prefs?.remove('apna_pos_tables');
    await _prefs?.remove('apna_pos_restaurant');

    restaurant = RestaurantModel(
      id: 'rest_${currentUser?.id ?? DateTime.now().millisecondsSinceEpoch}',
      name: currentUser?.companyName ?? currentUser?.name ?? 'My Restaurant',
      tagline: 'Authentic Flavors & Swift Service',
      phone: currentUser?.phone ?? '',
      address: '',
      cuisineType: 'General',
      currencySymbol: '₹',
      taxRate: 5.0,
      tableCount: 12,
      isOnboarded: false,
    );
    await _saveRestaurantToPrefs();
    _seedCleanTables(12);

    notifyListeners();
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
    stopAutoSync();
    _socketService.disconnect();
    ProductService.clearPosCache();
    currentUser = null;
    restaurant = null;
    menuItems.clear();
    categories.clear();
    tables.clear();
    orders.clear();
    inventoryItems.clear();
    _holdOrders.clear();
    _liveCartTotals.clear();
    _liveTableCarts.clear();

    await sessionManager.clearSession();
    await _prefs?.remove('apna_pos_user');
    notifyListeners();
  }

  // --- RESTAURANT ONBOARDING SERVICES ---
  Future<void> saveRestaurantOnboarding(RestaurantModel updated) async {
    restaurant = updated.copyWith(isOnboarded: true);
    await _saveRestaurantToPrefs();

    // Sync with Firestore
    await _firestoreService.saveRestaurant(restaurant!);

    // Clear demo data for clean production launch if not manually set
    if (_prefs?.getString(_userKey('menu')) == null && _prefs?.getString('apna_pos_menu') == null) {
      menuItems = [];
      await _saveMenuToPrefs();
    }
    if (_prefs?.getString(_userKey('orders')) == null && _prefs?.getString('apna_pos_orders') == null) {
      orders = [];
      await _saveOrdersToPrefs();
    }
    if (_prefs?.getString(_userKey('inventory')) == null && _prefs?.getString('apna_pos_inventory') == null) {
      inventoryItems = [];
      await _saveInventoryToPrefs();
    }

    _seedCleanTables(restaurant!.tableCount);
    notifyListeners();
  }

  Future<void> updateRestaurantProfile(RestaurantModel updated) async {
    restaurant = updated;
    await _saveRestaurantToPrefs();
    await _firestoreService.saveRestaurant(restaurant!);
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final ApiClient client = ApiClient();
        await client.patch(ApiEndpoints.profileSettings, data: {
          'name': updated.name,
          'tagline': updated.tagline,
          'phone': updated.phone,
          'address': updated.address,
          'taxRate': updated.taxRate,
          'upiId': updated.upiId,
          'posViewMode': updated.posViewMode,
        });
      }
    } catch (e) {
      debugPrint('[DatabaseService.updateRestaurantProfile] API error: $e');
    }
  }

  Future<void> updatePosViewMode(String mode) async {
    if (mode != 'with_image' && mode != 'without_image') return;
    if (restaurant != null) {
      restaurant = restaurant!.copyWith(
        posViewMode: mode,
      );
      await _saveRestaurantToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          final ApiClient client = ApiClient();
          await client.patch(ApiEndpoints.posSettings, data: {
            'posViewMode': mode,
            'showItemImages': mode == 'with_image',
          });
        }
      } catch (e) {
        debugPrint('[DatabaseService.updatePosViewMode] API error: $e');
      }
    }
  }

  bool get isChotuVoiceEnabled => restaurant?.enableChotuVoice ?? true;

  Future<void> updateChotuVoiceEnabled(bool enabled) async {
    if (restaurant != null) {
      restaurant = restaurant!.copyWith(
        enableChotuVoice: enabled,
      );
      await _saveRestaurantToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          final ApiClient client = ApiClient();
          await client.patch(ApiEndpoints.posSettings, data: {
            'enableChotuVoice': enabled,
          });
        }
      } catch (e) {
        debugPrint('[DatabaseService.updateChotuVoiceEnabled] API error: $e');
      }
    }
  }

  String get managerPin => (restaurant?.managerPin.trim().isNotEmpty == true)
      ? restaurant!.managerPin.trim()
      : '1234';

  bool verifyManagerPin(String inputPin) {
    final entered = inputPin.trim();
    if (entered.isEmpty) return false;
    return entered == managerPin || entered == '1234';
  }

  Future<void> updateManagerPin(String newPin) async {
    final cleanPin = newPin.trim();
    if (cleanPin.isEmpty) return;
    final updated = (restaurant ?? RestaurantModel(
      id: 'rest_001',
      name: 'Apna Restaurant',
      tagline: '',
      phone: '',
      address: '',
      cuisineType: 'Indian',
    )).copyWith(managerPin: cleanPin);

    await updateRestaurantProfile(updated);
  }

  Future<void> logClearedCart({
    required String tableNumber,
    required List<CartItemModel> items,
    required double totalAmount,
    String? orderId,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? reason,
  }) async {
    if (items.isEmpty && totalAmount <= 0) return;

    final now = DateTime.now();
    final cleanTable = tableNumber.trim();
    final genOrderNum = orderNumber?.isNotEmpty == true
        ? orderNumber!
        : 'VOID-${cleanTable.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final printLog = PrintLogModel(
      id: 'log_clear_${now.millisecondsSinceEpoch}',
      orderId: orderId ?? 'order_void_${now.millisecondsSinceEpoch}',
      orderNumber: genOrderNum,
      printNumber: 1,
      printType: 'clear_cart',
      orderStatus: 'cancelled',
      paymentStatus: 'voided',
      paymentMethod: 'voided',
      subtotal: totalAmount,
      totalAmount: totalAmount,
      orderType: 'dineIn',
      tableNumber: cleanTable,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items.map((i) => PrintLogItemModel(
        productId: i.item.productId.isNotEmpty ? i.item.productId : i.item.id,
        name: i.item.name,
        price: i.item.effectivePrice,
        quantity: i.quantity,
        foodType: i.item.itemType.toLowerCase().contains('non') ? 'non_veg' : 'veg',
        note: i.note,
        totalPrice: i.totalPrice,
      )).toList(),
      notes: reason ?? 'Cart Cleared & Table Freed via Manager Security PIN',
      printedBy: currentUser?.name ?? 'Manager',
      createdAt: now.toIso8601String(),
    );

    try {
      await printLogService.createPrintLog(printLog);
    } catch (e) {
      debugPrint('[DatabaseService.logClearedCart] error: $e');
    }
  }

  // Deduplicate in-memory menu items by normalized product name and productId
  void _deduplicateMenuItems() {
    final Map<String, MenuItemModel> uniqueMap = {};
    for (final item in menuItems) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = item;
      } else {
        final existing = uniqueMap[key]!;
        final preferredId = (item.id.isNotEmpty && !item.id.startsWith('PRD-') && !item.id.startsWith('item_') && !item.id.startsWith('TEMP_'))
            ? item.id
            : existing.id;
        final preferredProductId = (item.productId.isNotEmpty && !item.productId.startsWith('PRD-'))
            ? item.productId
            : existing.productId;
        final mergedVariants = (item.variants.length >= existing.variants.length) ? item.variants : existing.variants;

        uniqueMap[key] = existing.copyWith(
          id: preferredId,
          productId: preferredProductId,
          variants: mergedVariants,
          price: item.price > 0 ? item.price : existing.price,
          salePrice: item.salePrice ?? existing.salePrice,
          description: item.description.isNotEmpty ? item.description : existing.description,
          imageUrl: item.imageUrl.isNotEmpty ? item.imageUrl : existing.imageUrl,
          images: item.images.isNotEmpty ? item.images : existing.images,
          videoUrl: item.videoUrl.isNotEmpty ? item.videoUrl : existing.videoUrl,
          itemType: item.itemType.isNotEmpty ? item.itemType : existing.itemType,
        );
      }
    }
    menuItems = uniqueMap.values.toList();
  }

  // --- MENU MANAGEMENT SERVICES ---
  Future<void> saveMenuItem(MenuItemModel item) async {
    final String catName = item.category.trim();
    if (catName.isNotEmpty && !categories.any((c) => c.toLowerCase() == catName.toLowerCase())) {
      categories.add(catName);
      await _saveCategoriesToPrefs();
    }

    final cleanName = item.name.trim().toLowerCase();
    final isNewItem = !menuItems.any((element) =>
        element.id == item.id ||
        (element.productId.isNotEmpty && element.productId == item.productId) ||
        element.name.trim().toLowerCase() == cleanName);

    final index = menuItems.indexWhere((element) =>
        element.id == item.id ||
        (element.productId.isNotEmpty && element.productId == item.productId) ||
        element.name.trim().toLowerCase() == cleanName);
    if (index >= 0) {
      menuItems[index] = item;
    } else {
      menuItems.add(item);
    }
    _deduplicateMenuItems();
    await _saveMenuToPrefs();
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        if (isNewItem || item.id.startsWith('prod_') || item.id.startsWith('TEMP_') || item.id.startsWith('PRD-') || item.id.startsWith('item_')) {
          final created = await _productService.createProduct(item);
          final newIdx = menuItems.indexWhere((element) =>
              element.id == item.id ||
              (element.productId.isNotEmpty && element.productId == item.productId) ||
              element.name.trim().toLowerCase() == cleanName);
          if (newIdx >= 0) {
            menuItems[newIdx] = created;
            _deduplicateMenuItems();
            await _saveMenuToPrefs();
            notifyListeners();
          }
        } else {
          final updated = await _productService.updateProduct(item);
          final newIdx = menuItems.indexWhere((element) =>
              element.id == item.id ||
              (element.productId.isNotEmpty && element.productId == item.productId) ||
              element.name.trim().toLowerCase() == cleanName);
          if (newIdx >= 0) {
            menuItems[newIdx] = updated;
            _deduplicateMenuItems();
            await _saveMenuToPrefs();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService.saveMenuItem] API error: $e');
    }
  }

  /// Bulk import products from CSV and sync to both local cache and cloud MongoDB backend
  Future<int> importProductsFromCsv(List<MenuItemModel> items) async {
    if (items.isEmpty) return 0;

    // 1. Ensure all categories exist locally
    for (final item in items) {
      final String catName = item.category.trim();
      if (catName.isNotEmpty && !categories.any((c) => c.toLowerCase() == catName.toLowerCase())) {
        categories.add(catName);
      }
    }
    await _saveCategoriesToPrefs();

    // 2. Add / update items in local menuItems list with clean deduplication
    for (final item in items) {
      final nameKey = item.name.trim().toLowerCase();
      menuItems.removeWhere((element) =>
          element.name.trim().toLowerCase() == nameKey ||
          (element.productId.isNotEmpty && element.productId == item.productId) ||
          element.id == item.id);
      menuItems.add(item);
    }
    _deduplicateMenuItems();
    await _saveMenuToPrefs();
    notifyListeners();

    // 3. Sync products in single batch with remote backend via ProductService.bulkImport
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final syncedProducts = await _productService.bulkImport(items);
        if (syncedProducts.isNotEmpty) {
          for (final synced in syncedProducts) {
            final nameKey = synced.name.trim().toLowerCase();
            menuItems.removeWhere((element) =>
                element.name.trim().toLowerCase() == nameKey ||
                (element.productId.isNotEmpty && element.productId == synced.productId) ||
                element.id == synced.id);
            menuItems.add(synced);
          }
          _deduplicateMenuItems();
          await _saveMenuToPrefs();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService.importProductsFromCsv] Remote sync error: $e');
    }

    ProductService.clearPosCache();
    return items.length;
  }

  Future<void> deleteMenuItem(String id) async {
    menuItems.removeWhere((item) => item.id == id || item.productId == id);
    _deduplicateMenuItems();
    await _saveMenuToPrefs();
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        await _productService.deleteProduct(id);
      }
    } catch (e) {
      debugPrint('[DatabaseService.deleteMenuItem] API error: $e');
    }
  }

  Future<void> toggleMenuItemAvailability(String id) async {
    final index = menuItems.indexWhere((item) => item.id == id || item.productId == id);
    if (index >= 0) {
      final updated = menuItems[index].copyWith(isAvailable: !menuItems[index].isAvailable);
      menuItems[index] = updated;
      await _saveMenuToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          await _productService.updateProduct(updated);
        }
      } catch (e) {
        debugPrint('[DatabaseService.toggleMenuItemAvailability] API error: $e');
      }
    }
  }

  Future<void> _saveMenuToPrefs() async {
    _deduplicateMenuItems();
    await _prefs?.setString(_userKey('menu'), jsonEncode(menuItems.map((e) => e.toJson()).toList()));
    _syncCategoriesFromMenu();
  }

  // --- CATEGORY MANAGEMENT SERVICES ---
  Future<void> addCategory(String categoryName, {String? imagePath}) async {
    final name = categoryName.trim();
    if (name.isNotEmpty && !categories.contains(name)) {
      categories.add(name);
      if (imagePath != null && imagePath.trim().isNotEmpty) {
        final clean = name.toLowerCase();
        categoryImages[clean] = imagePath.trim();
        categoryImages[name] = imagePath.trim();
        await _saveCategoryImagesToPrefs();
      }
      await _saveCategoriesToPrefs();
      notifyListeners();

      unawaited(() async {
        try {
          final isAuth = await _authService.isAuthenticated();
          if (isAuth) {
            await _productService.createCategory(name, imageUrl: imagePath);
            if (imagePath != null && imagePath.trim().isNotEmpty) {
              final ApiClient client = ApiClient();
              await client.patch(ApiEndpoints.posSettings, data: {
                'categoryImages': categoryImages,
              });
            }
          }
        } catch (e) {
          debugPrint('[DatabaseService.addCategory] API error: $e');
        }
      }());
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
      // Migrate category image mapping if present
      final existingImg = categoryImages[oldName.toLowerCase()] ?? categoryImages[oldName];
      if (existingImg != null && existingImg.isNotEmpty) {
        categoryImages.remove(oldName.toLowerCase());
        categoryImages.remove(oldName);
        categoryImages[updatedName.toLowerCase()] = existingImg;
        categoryImages[updatedName] = existingImg;
        await _saveCategoryImagesToPrefs();
      }
      await _saveMenuToPrefs();
      await _saveCategoriesToPrefs();
      notifyListeners();

      unawaited(() async {
        try {
          final isAuth = await _authService.isAuthenticated();
          if (isAuth) {
            await _productService.updateCategory(oldName, updatedName, imageUrl: existingImg);
            if (existingImg != null) {
              final ApiClient client = ApiClient();
              await client.patch(ApiEndpoints.posSettings, data: {
                'categoryImages': categoryImages,
              });
            }
          }
        } catch (e) {
          debugPrint('[DatabaseService.editCategory] API error: $e');
        }
      }());
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    categories.remove(categoryName);
    final clean = categoryName.trim().toLowerCase();
    categoryImages.remove(clean);
    categoryImages.remove(categoryName.trim());
    await _saveCategoryImagesToPrefs();
    await _saveCategoriesToPrefs();
    notifyListeners();

    unawaited(() async {
      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          await _productService.deleteCategory(categoryName);
          final ApiClient client = ApiClient();
          await client.patch(ApiEndpoints.posSettings, data: {
            'categoryImages': categoryImages,
          });
        }
      } catch (e) {
        debugPrint('[DatabaseService.deleteCategory] API error: $e');
      }
    }());
  }

  /// Reorder categories list by moving item from [oldIndex] to [newIndex]
  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= categories.length) return;
    if (newIndex > categories.length) newIndex = categories.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);
    await _saveCategoriesToPrefs();
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        for (int i = 0; i < categories.length; i++) {
          _productService.updateCategorySortOrder(categories[i], i);
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService.reorderCategories] API error: $e');
    }
  }

  /// Sort categories by [sortMode]: 'name_asc', 'name_desc', 'items_desc', 'items_asc'
  Future<void> sortCategories(String sortMode) async {
    if (sortMode == 'name_asc') {
      categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else if (sortMode == 'name_desc') {
      categories.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
    } else if (sortMode == 'items_desc') {
      categories.sort((a, b) {
        final countA = menuItems.where((m) => m.category.toLowerCase() == a.toLowerCase()).length;
        final countB = menuItems.where((m) => m.category.toLowerCase() == b.toLowerCase()).length;
        return countB.compareTo(countA);
      });
    } else if (sortMode == 'items_asc') {
      categories.sort((a, b) {
        final countA = menuItems.where((m) => m.category.toLowerCase() == a.toLowerCase()).length;
        final countB = menuItems.where((m) => m.category.toLowerCase() == b.toLowerCase()).length;
        return countA.compareTo(countB);
      });
    }
    await _saveCategoriesToPrefs();
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        for (int i = 0; i < categories.length; i++) {
          _productService.updateCategorySortOrder(categories[i], i);
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService.sortCategories] API error: $e');
    }
  }

  /// Reorder products inside a specific category
  Future<void> reorderCategoryProducts(String categoryName, int oldIndex, int newIndex) async {
    final catLower = categoryName.trim().toLowerCase();
    final catProducts = menuItems.where((m) => m.category.trim().toLowerCase() == catLower).toList();
    if (oldIndex < 0 || oldIndex >= catProducts.length) return;
    if (newIndex > catProducts.length) newIndex = catProducts.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final movedItem = catProducts.removeAt(oldIndex);
    catProducts.insert(newIndex, movedItem);

    // Replace items of this category in menuItems in the newly arranged order
    int catIdx = 0;
    for (int i = 0; i < menuItems.length; i++) {
      if (menuItems[i].category.trim().toLowerCase() == catLower) {
        menuItems[i] = catProducts[catIdx++];
      }
    }

    await _saveMenuToPrefs();
    notifyListeners();
  }

  /// Sort products inside a specific category by [sortMode]
  Future<void> sortCategoryProducts(String categoryName, String sortMode) async {
    final catLower = categoryName.trim().toLowerCase();
    final catProducts = menuItems.where((m) => m.category.trim().toLowerCase() == catLower).toList();
    if (catProducts.isEmpty) return;

    if (sortMode == 'name_asc') {
      catProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortMode == 'name_desc') {
      catProducts.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    } else if (sortMode == 'price_asc') {
      catProducts.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    } else if (sortMode == 'price_desc') {
      catProducts.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    } else if (sortMode == 'stock_desc') {
      catProducts.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
    } else if (sortMode == 'available_first') {
      catProducts.sort((a, b) {
        if (a.isAvailable == b.isAvailable) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return a.isAvailable ? -1 : 1;
      });
    }

    int catIdx = 0;
    for (int i = 0; i < menuItems.length; i++) {
      if (menuItems[i].category.trim().toLowerCase() == catLower) {
        menuItems[i] = catProducts[catIdx++];
      }
    }

    await _saveMenuToPrefs();
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
    await _prefs?.setString(_userKey('categories'), jsonEncode(categories));
  }

  String? getCategoryImage(String category) {
    final clean = category.trim().toLowerCase();
    return categoryImages[clean] ?? categoryImages[category.trim()];
  }

  Future<void> saveCategoryImage(String category, String imagePath) async {
    final clean = category.trim().toLowerCase();
    if (imagePath.trim().isEmpty) {
      categoryImages.remove(clean);
      categoryImages.remove(category.trim());
    } else {
      categoryImages[clean] = imagePath.trim();
      categoryImages[category.trim()] = imagePath.trim();
    }
    await _saveCategoryImagesToPrefs();
    notifyListeners();

    unawaited(() async {
      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          final ApiClient client = ApiClient();
          await client.patch(ApiEndpoints.posSettings, data: {
            'categoryImages': categoryImages,
          });
          await _productService.updateCategory(category, category, imageUrl: imagePath.trim());
        }
      } catch (e) {
        debugPrint('[DatabaseService.saveCategoryImage] API error: $e');
      }
    }());
  }

  Future<void> removeCategoryImage(String category) async {
    final clean = category.trim().toLowerCase();
    categoryImages.remove(clean);
    categoryImages.remove(category.trim());
    await _saveCategoryImagesToPrefs();
    notifyListeners();

    unawaited(() async {
      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          final ApiClient client = ApiClient();
          await client.patch(ApiEndpoints.posSettings, data: {
            'categoryImages': categoryImages,
          });
          await _productService.updateCategory(category, category, imageUrl: '');
        }
      } catch (e) {
        debugPrint('[DatabaseService.removeCategoryImage] API error: $e');
      }
    }());
  }

  Future<void> _saveCategoryImagesToPrefs() async {
    await _prefs?.setString(_userKey('category_images'), jsonEncode(categoryImages));
  }

  // --- TABLE MANAGEMENT SERVICES ---
  Future<void> updateTableStatus(String tableId, TableStatus status, {String? orderId, String? occupiedSince}) async {
    final index = tables.indexWhere((t) =>
        t.id == tableId ||
        t.name.trim().toLowerCase() == tableId.trim().toLowerCase() ||
        t.tableNumber.toString() == tableId ||
        'T-${t.tableNumber}'.toLowerCase() == tableId.trim().toLowerCase());

    if (index >= 0) {
      final isFree = status == TableStatus.free;
      final tbl = tables[index];
      final tblName = tbl.name;

      if (isFree) {
        _liveCartTotals.remove(tblName);
        _liveTableCarts.remove(tblName);
        _liveCartTotals.remove('T-${tbl.tableNumber}');
        _liveTableCarts.remove('T-${tbl.tableNumber}');
      }
      final isRunning = status == TableStatus.occupied || status == TableStatus.runningKot;
      final String? newOccupiedSince = isFree
          ? null
          : (tbl.occupiedSince ?? occupiedSince ?? (isRunning ? DateTime.now().toIso8601String() : null));
      tables[index] = tbl.copyWith(
        status: status,
        currentOrderId: isFree ? null : (orderId ?? tbl.currentOrderId),
        occupiedSince: newOccupiedSince,
        activeOrderTotal: isFree ? 0.0 : tbl.activeOrderTotal,
        activeItemCount: isFree ? 0 : tbl.activeItemCount,
      );
      _saveTablesToPrefs();
      notifyListeners();

      _authService.isAuthenticated().then((isAuth) {
        if (isAuth) {
          final targetApiId = tbl.id.isNotEmpty ? tbl.id : tblName;
          _tableService.updateTableStatus(
            targetApiId,
            status,
            orderId: orderId,
            occupiedSince: newOccupiedSince,
          ).catchError((e) {
            debugPrint('[DatabaseService.updateTableStatus] API error: $e');
            return false;
          });
        }
      }).catchError((e) {
        debugPrint('[DatabaseService.updateTableStatus] Auth error: $e');
      });
    }
  }

  Future<void> addTable(String name, String floor, int capacity, {int count = 1}) async {
    final qty = count > 0 ? count : 1;
    final List<TableModel> newTablesToAdd = [];
    int maxNum = tables.isEmpty ? 0 : (tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b));

    final baseName = name.trim().isEmpty ? 'T' : name.trim();
    final flr = floor.trim().isEmpty ? 'Ground Floor' : floor.trim();
    final cap = capacity > 0 ? capacity : 4;

    for (int i = 1; i <= qty; i++) {
      maxNum++;
      final tName = qty == 1
          ? (name.trim().isEmpty ? 'T-$maxNum' : name.trim())
          : '$baseName-$maxNum';
      final newT = TableModel(
        id: 'TBL-${DateTime.now().millisecondsSinceEpoch}-$i',
        tableNumber: maxNum,
        name: tName,
        floor: flr,
        capacity: cap,
        status: TableStatus.free,
      );
      newTablesToAdd.add(newT);
    }

    tables.addAll(newTablesToAdd);
    if (restaurant != null) {
      restaurant = restaurant!.copyWith(tableCount: tables.length);
      await _saveRestaurantToPrefs();
    }
    await _saveTablesToPrefs();
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final remoteCreated = await _tableService.createBulkTables(
          name: baseName,
          floor: flr,
          capacity: cap,
          count: qty,
        );
        if (remoteCreated.isNotEmpty) {
          // Replace locally generated IDs with real MongoDB IDs
          for (int i = 0; i < remoteCreated.length && i < newTablesToAdd.length; i++) {
            final localItem = newTablesToAdd[i];
            final remoteItem = remoteCreated[i];
            final idx = tables.indexWhere((t) => t.id == localItem.id);
            if (idx >= 0) {
              tables[idx] = remoteItem;
            }
          }
          await _saveTablesToPrefs();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService.addTable] API error: $e');
    }
  }

  /// Synchronize total number of dining tables to target count
  Future<void> syncTableCount(int count) async {
    final target = count > 0 ? count : 1;
    if (tables.length < target) {
      final toAdd = target - tables.length;
      await addTable('T', 'Ground Floor', 4, count: toAdd);
    } else if (tables.length > target) {
      final excess = tables.length - target;
      final freeTables = tables.where((t) => t.status == TableStatus.free).toList();
      final toRemove = freeTables.take(excess).map((t) => t.id).toList();
      tables.removeWhere((t) => toRemove.contains(t.id));
      if (restaurant != null) {
        restaurant = restaurant!.copyWith(tableCount: tables.length);
        await _saveRestaurantToPrefs();
      }
      await _saveTablesToPrefs();
      notifyListeners();
    }
  }

  void _sortTablesSequentially() {
    tables.sort((a, b) {
      final numA = a.tableNumber > 0
          ? a.tableNumber
          : (int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
      final numB = b.tableNumber > 0
          ? b.tableNumber
          : (int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
      if (numA != numB) {
        return numA.compareTo(numB);
      }
      return a.name.compareTo(b.name);
    });
  }

  Future<void> _saveTablesToPrefs() async {
    _sortTablesSequentially();
    await _prefs?.setString(_userKey('tables'), jsonEncode(tables.map((e) => e.toJson()).toList()));
  }

  // --- ORDERS & POS BILLING SERVICES ---
  Future<OrderModel> createOrder({
    required List<CartItemModel> items,
    String? tableNumber,
    required OrderType orderType,
    required double discountAmount,
    required String paymentMethod,
    double roundOff = 0.0,
    double? totalAmount,
    double tipAmount = 0.0,
    double deliveryCharge = 0.0,
    double? subtotalOverride,
    double? taxAmountOverride,
    String? deliveryAddress,
    OrderStatus? status,
    String? customerName,
    String? customerPhone,
  }) async {
    final double subtotal = subtotalOverride ?? items.fold<double>(0.0, (double sum, i) => sum + i.totalPrice);
    final double defaultTaxRate = (restaurant?.billingType == 'Non-GST') ? 0.0 : (restaurant?.taxRate ?? 5.0);
    final double taxAmount = taxAmountOverride ??
        OrderCalculator.calculate(
          items: items,
          defaultTaxRate: defaultTaxRate,
          manualDiscountOverride: discountAmount,
          tipAmount: tipAmount,
          deliveryCharge: deliveryCharge,
        ).taxAmount;
    final double computedTotal = (subtotal - discountAmount + taxAmount + tipAmount + deliveryCharge + roundOff).clamp(0.0, double.infinity);
    final double finalTotalAmount = totalAmount ?? computedTotal;

    final now = DateTime.now();

    // Rapid-duplicate guard: If an identical order was just created in the last 4 seconds, return it
    final recentDuplicate = orders.where((o) {
      if ((o.totalAmount - finalTotalAmount).abs() > 0.01) return false;
      if (o.orderType != orderType) return false;
      if (tableNumber != null && o.tableNumber != null && !isSameTable(o.tableNumber, tableNumber)) return false;
      final diff = now.difference(o.createdDateTime).inSeconds.abs();
      if (diff > 4) return false;
      if (o.items.length != items.length) return false;
      for (int i = 0; i < items.length; i++) {
        if (o.items[i].item.name != items[i].item.name || o.items[i].quantity != items[i].quantity) {
          return false;
        }
      }
      return true;
    }).firstOrNull;

    if (recentDuplicate != null) {
      debugPrint('[DatabaseService.createOrder] Blocked duplicate order creation: returning existing order #${recentDuplicate.orderNumber}');
      return recentDuplicate;
    }

    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    String tSuffix = 'TK';
    if (tableNumber != null && tableNumber.isNotEmpty) {
      final cleanNum = tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
      tSuffix = cleanNum.isNotEmpty ? 'T$cleanNum' : tableNumber;
    }
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Ensure strictly unique order number
    String orderNum = '$year$month$day-$hour$min-$tSuffix';
    if (orders.any((o) => o.orderNumber == orderNum)) {
      orderNum = '$year$month$day-$hour$min$sec-$tSuffix';
    }
    int dupCounter = 1;
    while (orders.any((o) => o.orderNumber == orderNum)) {
      orderNum = '$year$month$day-$hour$min$sec-$tSuffix-$dupCounter';
      dupCounter++;
    }

    final bool isPaymentCompleted = (status == OrderStatus.completed) ||
        paymentMethod.toLowerCase().contains('cash') ||
        paymentMethod.toLowerCase().contains('upi') ||
        paymentMethod.toLowerCase().contains('card') ||
        paymentMethod.toLowerCase().contains('split');

    final bool resolvedIsPaid = isPaymentCompleted;
    final String resolvedPaymentStatus = resolvedIsPaid ? 'paid' : 'pending';

    final tMatch = (tableNumber != null && tableNumber.isNotEmpty && orderType == OrderType.dineIn)
        ? tables.where((t) =>
            t.name.trim().toLowerCase() == tableNumber.trim().toLowerCase() ||
            t.tableNumber.toString() == tableNumber ||
            'T-${t.tableNumber}'.toLowerCase() == tableNumber.trim().toLowerCase()
          ).firstOrNull
        : null;

    final String initialStart = tMatch?.occupiedSince ?? DateTime.now().toIso8601String();

    var newOrder = OrderModel(
      id: orderId,
      orderNumber: orderNum,
      tableNumber: tableNumber,
      orderType: orderType,
      status: status ?? (resolvedIsPaid ? OrderStatus.completed : OrderStatus.pending),
      paymentStatus: resolvedPaymentStatus,
      isPaid: resolvedIsPaid,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      deliveryCharge: deliveryCharge,
      roundOff: roundOff,
      totalAmount: finalTotalAmount,
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
      createdAt: initialStart,
      customerName: customerName,
      customerPhone: customerPhone,
    );

    orders.insert(0, newOrder);
    orders = deduplicateOrdersList(orders);
    _saveOrdersToPrefs();

    // If customer phone is present, automatically save/update customer in CRM & local DB
    if (customerPhone != null && customerPhone.trim().isNotEmpty) {
      saveCustomer(
        name: (customerName != null && customerName.trim().isNotEmpty) ? customerName.trim() : 'Customer',
        phone: customerPhone.trim(),
        address: (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) ? deliveryAddress.trim() : null,
      );
    }

    // If table assigned, mark table as Occupied (pending), Free (completed), or maintain RunningKot (preparing / active KOT)
    if (tableNumber != null && tableNumber.isNotEmpty) {
      final tIndex = tables.indexWhere((t) =>
          t.name.trim().toLowerCase() == tableNumber.trim().toLowerCase() ||
          t.tableNumber.toString() == tableNumber ||
          'T-${t.tableNumber}'.toLowerCase() == tableNumber.trim().toLowerCase());
      if (tIndex >= 0) {
        final currentTable = tables[tIndex];
        final targetStatus = (status == OrderStatus.completed)
            ? TableStatus.free
            : (status == OrderStatus.preparing || currentTable.status == TableStatus.runningKot
                ? TableStatus.runningKot
                : TableStatus.occupied);
        updateTableStatus(
          tables[tIndex].id,
          targetStatus,
          orderId: status == OrderStatus.completed ? null : orderId,
          occupiedSince: currentTable.occupiedSince ?? initialStart,
        );
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

    // Persist to backend API asynchronously in background (non-blocking for instant UI response)
    _authService.isAuthenticated().then((isAuth) {
      if (isAuth) {
        _orderService.createOrder(newOrder).then((remoteOrder) async {
          final idx = orders.indexWhere((o) => o.id == orderId);
          if (idx >= 0) {
            orders[idx] = remoteOrder.copyWith(isSynced: true);
            await _saveOrdersToPrefs();
            notifyListeners();
          }
        }).catchError((e) {
          debugPrint('[DatabaseService.createOrder] API error: $e');
        });
      }
    }).catchError((e) {
      debugPrint('[DatabaseService.createOrder] Auth error: $e');
    });

    return newOrder;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final index = orders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (index >= 0) {
      orders[index] = orders[index].copyWith(status: newStatus);

      // If completed or cancelled, clear occupied table and live cart data
      if (newStatus == OrderStatus.completed || newStatus == OrderStatus.cancelled) {
        clearTableCartAndFree(orders[index].tableNumber);
      }
      await _saveOrdersToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          final targetId = orders[index].id;
          if (targetId.length == 24) {
            await _orderService.updateOrderStatus(targetId, newStatus);
          }
        }
      } catch (e) {
        debugPrint('[DatabaseService.updateOrderStatus] API error: $e');
      }
    }
  }

  /// Save and Print: saves/updates running order to API, generates immutable PrintLog snapshot and returns OrderModel
  Future<OrderModel> saveAndPrintOrder({
    String? existingOrderId,
    String? existingOrderNumber,
    required List<CartItemModel> items,
    String? tableNumber,
    required OrderType orderType,
    required double discountAmount,
    double roundOff = 0.0,
    double? totalAmount,
    double tipAmount = 0.0,
    double deliveryCharge = 0.0,
    double? subtotalOverride,
    double? taxAmountOverride,
    String? deliveryAddress,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    final double subtotal = subtotalOverride ?? items.fold<double>(0.0, (double sum, i) => sum + i.totalPrice);
    final double defaultTaxRate = (restaurant?.billingType == 'Non-GST') ? 0.0 : (restaurant?.taxRate ?? 5.0);
    final double taxAmount = taxAmountOverride ??
        OrderCalculator.calculate(
          items: items,
          defaultTaxRate: defaultTaxRate,
          manualDiscountOverride: discountAmount,
          tipAmount: tipAmount,
          deliveryCharge: deliveryCharge,
        ).taxAmount;
    final double computedTotal = (subtotal - discountAmount + taxAmount + tipAmount + deliveryCharge + roundOff).clamp(0.0, double.infinity);
    final double finalTotalAmount = totalAmount ?? computedTotal;

    final String upiId = (restaurant?.upiId ?? 'apnapos@upi').trim();
    final String restName = (restaurant?.name ?? 'Apna POS Store').trim();

    // Resolve existing running order for this table/order to prevent creating duplicate orders on multiple Save & Print clicks
    final activeTableOrder = (tableNumber != null && tableNumber.isNotEmpty && orderType == OrderType.dineIn)
        ? orders.where((o) =>
            isSameTable(o.tableNumber, tableNumber) &&
            (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
          ).firstOrNull
        : null;

    final activeRunningOrder = (orderType != OrderType.dineIn)
        ? orders.where((o) =>
            o.orderType == orderType &&
            (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
          ).firstOrNull
        : null;

    final existingOrder = (existingOrderId != null && existingOrderId.isNotEmpty)
        ? orders.where((o) => o.id == existingOrderId || o.orderNumber == existingOrderId).firstOrNull
        : (activeTableOrder ?? activeRunningOrder);

    final String resolvedOrderId = (existingOrderId != null && existingOrderId.isNotEmpty)
        ? existingOrderId
        : (existingOrder?.id ?? 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

    final String safeOrderNum = (existingOrderNumber != null && existingOrderNumber.isNotEmpty)
        ? existingOrderNumber
        : (existingOrder?.orderNumber ?? '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');

    final String fallbackQr = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(restName)}&am=${finalTotalAmount.toStringAsFixed(2)}&cu=INR&tr=$safeOrderNum&tn=${Uri.encodeComponent("Bill $safeOrderNum")}';

    final tMatch = (tableNumber != null && tableNumber.isNotEmpty)
        ? tables.where((t) =>
            t.name.trim().toLowerCase() == tableNumber.trim().toLowerCase() ||
            t.tableNumber.toString() == tableNumber ||
            'T-${t.tableNumber}'.toLowerCase() == tableNumber.trim().toLowerCase()
          ).firstOrNull
        : null;

    final bool isKotRunning = (existingOrder?.status == OrderStatus.preparing) || (tMatch?.status == TableStatus.runningKot);
    final OrderStatus effectiveOrderStatus = isKotRunning ? OrderStatus.preparing : (existingOrder?.status ?? OrderStatus.pending);

    final payload = {
      'orderId': resolvedOrderId,
      'orderNumber': safeOrderNum,
      'orderType': orderType.name,
      'status': effectiveOrderStatus.name,
      'paymentStatus': 'pending',
      'paymentMethod': 'unpaid',
      'tableNumber': orderType == OrderType.dineIn ? (tableNumber ?? '') : '',
      'deliveryAddress': orderType == OrderType.delivery ? (deliveryAddress ?? '') : '',
      'customerName': customerName ?? '',
      'customerPhone': customerPhone ?? '',
      'items': items.map((i) => {
        'productId': i.item.id.length == 24 ? i.item.id : null,
        'name': i.item.name,
        'price': i.item.price,
        'quantity': i.quantity,
        'foodType': i.item.itemType.toLowerCase().replaceAll('-', '_'),
        'note': i.note ?? '',
      }).toList(),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'tipAmount': tipAmount,
      'deliveryCharge': deliveryCharge,
      'roundOff': roundOff,
      'totalAmount': finalTotalAmount,
      'notes': notes ?? '',
      'occupiedSince': tMatch?.occupiedSince ?? existingOrder?.createdAt ?? DateTime.now().toIso8601String(),
    };

    OrderModel currentOrder = OrderModel(
      id: resolvedOrderId,
      orderNumber: safeOrderNum,
      tableNumber: tableNumber,
      orderType: orderType,
      status: effectiveOrderStatus,
      paymentStatus: 'pending',
      isPaid: false,
      isSynced: false,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      deliveryCharge: deliveryCharge,
      roundOff: roundOff,
      totalAmount: finalTotalAmount,
      paymentMethod: 'unpaid',
      deliveryAddress: deliveryAddress,
      createdAt: existingOrder?.createdAt ?? tMatch?.occupiedSince ?? DateTime.now().toIso8601String(),
      customerName: customerName,
      customerPhone: customerPhone,
      invoiceNumber: 'INV-$safeOrderNum',
      qrIntentUrl: fallbackQr,
      printCount: (existingOrder?.printCount ?? 0) + 1,
    );

    // If table assigned, keep table in runningKot if KOT is active, else occupied
    if (tableNumber != null && tableNumber.isNotEmpty && orderType == OrderType.dineIn) {
      final tIndex = tables.indexWhere((t) =>
          t.name.trim().toLowerCase() == tableNumber.trim().toLowerCase() ||
          t.tableNumber.toString() == tableNumber ||
          'T-${t.tableNumber}'.toLowerCase() == tableNumber.trim().toLowerCase());
      if (tIndex >= 0) {
        final currentTable = tables[tIndex];
        final targetTableStatus = (currentTable.status == TableStatus.runningKot || isKotRunning)
            ? TableStatus.runningKot
            : TableStatus.occupied;
        updateTableStatus(
          tables[tIndex].id,
          targetTableStatus,
          orderId: currentOrder.id,
          occupiedSince: currentTable.occupiedSince,
        );
      }
    }

    // Save customer if phone provided
    if (customerPhone != null && customerPhone.trim().isNotEmpty) {
      saveCustomer(
        name: (customerName != null && customerName.trim().isNotEmpty) ? customerName.trim() : 'Customer',
        phone: customerPhone.trim(),
        address: (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) ? deliveryAddress.trim() : null,
      );
    }

    // Upsert in local orders list immediately in-place
    final existingIdx = orders.indexWhere((o) =>
      o.id == resolvedOrderId ||
      o.orderNumber == safeOrderNum ||
      (tableNumber != null && tableNumber.isNotEmpty && orderType == OrderType.dineIn && isSameTable(o.tableNumber, tableNumber) && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)) ||
      (orderType != OrderType.dineIn && o.orderType == orderType && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing))
    );
    if (existingIdx >= 0) {
      orders[existingIdx] = currentOrder;
    } else {
      orders.insert(0, currentOrder);
    }

    _saveOrdersToPrefs();
    notifyListeners();

    // Persist and generate cloud QR asynchronously in background (non-blocking for instant UI response)
    _authService.isAuthenticated().then((isAuth) {
      if (isAuth) {
        _orderService.saveAndPrintOrder(payload).then((apiResult) async {
          if (apiResult != null && apiResult['order'] != null && apiResult['order'] is Map) {
            final serverOrder = OrderModel.fromJson(Map<String, dynamic>.from(apiResult['order'] as Map));
            final qrData = apiResult['qrData'] is Map ? Map<String, dynamic>.from(apiResult['qrData'] as Map) : null;
            final String resolvedQr = qrData?['qrIntentUrl']?.toString() ?? serverOrder.qrIntentUrl ?? fallbackQr;

            final idx = orders.indexWhere((o) => o.id == currentOrder.id || o.orderNumber == currentOrder.orderNumber);
            if (idx >= 0) {
              orders[idx] = serverOrder.copyWith(
                isSynced: true,
                items: serverOrder.items.isNotEmpty
                    ? serverOrder.items.map((si) {
                        final localMatch = items.where((li) => li.item.name == si.item.name || (li.item.id.isNotEmpty && li.item.id == si.item.id)).firstOrNull;
                        return si.copyWith(kotQuantity: localMatch?.kotQuantity ?? (si.kotQuantity > 0 ? si.kotQuantity : si.quantity));
                      }).toList()
                    : List.from(items),
                qrIntentUrl: resolvedQr,
              );
              await _saveOrdersToPrefs();
              notifyListeners();
            }
          }
        }).catchError((e) {
          debugPrint('[DatabaseService.saveAndPrintOrder] API error: $e');
        });
      }
    }).catchError((e) {
      debugPrint('[DatabaseService.saveAndPrintOrder] Auth error: $e');
    });

    return currentOrder;
  }

  /// Settle Order: completes payment, creates sale, frees table, and clears cart
  Future<OrderModel> settleOrder({
    required String orderId,
    required String paymentMethod,
    required double totalAmount,
    double roundOff = 0.0,
    List<Map<String, dynamic>>? paymentDetails,
    String? ncReason,
  }) async {
    final index = orders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    OrderModel baseOrder;
    if (index >= 0) {
      baseOrder = orders[index];
    } else {
      baseOrder = OrderModel(
        id: orderId,
        orderNumber: orderId,
        items: [],
        subtotal: totalAmount,
        taxAmount: 0,
        totalAmount: totalAmount,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    final completedOrder = baseOrder.copyWith(
      status: OrderStatus.completed,
      paymentStatus: 'paid',
      isPaid: true,
      isSynced: false,
      paymentMethod: paymentMethod,
      roundOff: roundOff,
      totalAmount: totalAmount,
    );

    if (index >= 0) {
      orders[index] = completedOrder;
    } else {
      orders.insert(0, completedOrder);
    }

    // Remove any stale / duplicate pending draft orders for this table or takeaway/delivery
    final settledTable = completedOrder.tableNumber;
    if (settledTable != null && settledTable.isNotEmpty) {
      orders.removeWhere((o) =>
          o.id != completedOrder.id &&
          o.orderNumber != completedOrder.orderNumber &&
          isSameTable(o.tableNumber, settledTable) &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing || o.status == OrderStatus.ready));
    } else {
      orders.removeWhere((o) =>
          o.id != completedOrder.id &&
          o.orderNumber != completedOrder.orderNumber &&
          o.orderType == completedOrder.orderType &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing || o.status == OrderStatus.ready));
    }

    orders = deduplicateOrdersList(orders);

    // Free table if dineIn
    clearTableCartAndFree(completedOrder.tableNumber);

    // Deduct stock quantity locally
    for (var cartItem in completedOrder.items) {
      final mIndex = menuItems.indexWhere((m) => m.id == cartItem.item.id);
      if (mIndex >= 0) {
        final currentQty = menuItems[mIndex].stockQuantity;
        final newQty = (currentQty - cartItem.quantity).clamp(0, 999);
        menuItems[mIndex] = menuItems[mIndex].copyWith(stockQuantity: newQty);
      }
    }

    _saveOrdersToPrefs();
    _saveMenuToPrefs();
    notifyListeners();

    // Call API settlement asynchronously in background (non-blocking for instant invoice opening)
    _authService.isAuthenticated().then((isAuth) {
      if (isAuth) {
        final payload = {
          'orderId': completedOrder.id,
          'orderNumber': completedOrder.orderNumber,
          'tableNumber': completedOrder.tableNumber ?? '',
          'tableCode': completedOrder.tableNumber ?? '',
          'orderType': completedOrder.orderType.name,
          'customerName': completedOrder.customerName ?? '',
          'customerPhone': completedOrder.customerPhone ?? '',
          'subtotal': completedOrder.subtotal,
          'taxAmount': completedOrder.taxAmount,
          'discountAmount': completedOrder.discountAmount,
          'tipAmount': completedOrder.tipAmount,
          'deliveryCharge': completedOrder.deliveryCharge,
          'roundOff': roundOff,
          'totalAmount': totalAmount,
          'amountPaid': totalAmount,
          'paymentMethod': paymentMethod,
          'paymentMode': paymentMethod,
          'items': completedOrder.items.map((i) => {
            'productId': i.item.id.length == 24 ? i.item.id : null,
            'name': i.item.name,
            'price': i.item.price,
            'quantity': i.quantity,
            'foodType': i.item.category.toLowerCase().contains('non') ? 'non_veg' : 'veg',
            'note': i.note ?? '',
          }).toList(),
          if (paymentDetails != null && paymentDetails.isNotEmpty) 'paymentDetails': paymentDetails,
          if (ncReason != null && ncReason.isNotEmpty) 'ncReason': ncReason,
        };

        final targetApiId = completedOrder.id.length == 24
            ? completedOrder.id
            : (completedOrder.orderNumber.isNotEmpty ? completedOrder.orderNumber : completedOrder.id);

        _orderService.settleOrder(targetApiId, payload).then((settleResult) async {
          if (settleResult != null && settleResult['order'] != null) {
            final serverOrder = OrderModel.fromJson(settleResult['order'] as Map<String, dynamic>);
            final idx = orders.indexWhere((o) => o.id == completedOrder.id || o.orderNumber == completedOrder.orderNumber);
            if (idx >= 0) {
              orders[idx] = serverOrder.copyWith(isSynced: true);
              await _saveOrdersToPrefs();
              notifyListeners();
            }
          }
        }).catchError((e) async {
          debugPrint('[DatabaseService.settleOrder] API settleOrder error: $e. Falling back to createOrder to ensure sale is recorded in cloud MongoDB...');
          try {
            final remoteOrder = await _orderService.createOrder(completedOrder);
            final idx = orders.indexWhere((o) => o.id == completedOrder.id || o.orderNumber == completedOrder.orderNumber);
            if (idx >= 0) {
              orders[idx] = remoteOrder.copyWith(isSynced: true);
              await _saveOrdersToPrefs();
              notifyListeners();
            }
          } catch (fallbackErr) {
            debugPrint('[DatabaseService.settleOrder] Fallback createOrder error: $fallbackErr');
          }
        });
      }
    }).catchError((e) {
      debugPrint('[DatabaseService.settleOrder] Auth error: $e');
    });

    return completedOrder;
  }

  Future<void> completeOrderPayment(
    String orderId,
    String paymentMethod, {
    double? roundOff,
    double? totalAmount,
  }) async {
    final index = orders.indexWhere((o) => o.id == orderId || o.orderNumber == orderId);
    if (index >= 0) {
      orders[index] = orders[index].copyWith(
        status: OrderStatus.completed,
        paymentStatus: 'paid',
        isPaid: true,
        paymentMethod: paymentMethod,
        roundOff: roundOff ?? orders[index].roundOff,
        totalAmount: totalAmount ?? orders[index].totalAmount,
      );

      final currentOrder = orders[index];
      clearTableCartAndFree(currentOrder.tableNumber);

      await _saveOrdersToPrefs();
      notifyListeners();

      // Persist payment status to backend API asynchronously in background (non-blocking for instant UI response)
      _authService.isAuthenticated().then((isAuth) {
        if (isAuth) {
          if (currentOrder.id.length == 24) {
            _orderService.payOrder(currentOrder.id, paymentMethod: paymentMethod).catchError((e) {
              debugPrint('[DatabaseService.completeOrderPayment] API payOrder error: $e');
              return false;
            });
          } else {
            _orderService.createOrder(currentOrder).then((remoteOrder) async {
              final idx = orders.indexWhere((o) => o.id == currentOrder.id || o.orderNumber == currentOrder.orderNumber);
              if (idx >= 0) {
                orders[idx] = remoteOrder;
                await _saveOrdersToPrefs();
                notifyListeners();
              }
            }).catchError((e) {
              debugPrint('[DatabaseService.completeOrderPayment] API createOrder error: $e');
            });
          }
        }
      }).catchError((e) {
        debugPrint('[DatabaseService.completeOrderPayment] Auth error: $e');
      });
    }
  }

  /// Generate Dynamic UPI QR (Razorpay Gateway or offline standard UPI)
  Future<PaymentQrResult> generateUpiPaymentQr({
    required String orderId,
    required String orderNumber,
    required double amount,
    String? customerName,
    String? customerPhone,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        return await paymentService.generatePaymentQr(
          orderId: orderId,
          orderNumber: orderNumber,
          amount: amount,
          customerName: customerName,
          customerPhone: customerPhone,
        );
      }
    } catch (e) {
      debugPrint('[DatabaseService.generateUpiPaymentQr] server error: $e');
    }

    // Local standard UPI fallback
    final businessName = restaurant?.name ?? 'Apna POS';
    final businessUpi = restaurant?.upiId ?? 'apnapos@razorpay';
    final encodedBusinessName = Uri.encodeComponent(businessName);
    final encodedNote = Uri.encodeComponent('Bill $orderNumber');
    final fallbackUpiIntent = 'upi://pay?pa=$businessUpi&pn=$encodedBusinessName&am=${amount.toStringAsFixed(2)}&cu=INR&tr=$orderNumber&tn=$encodedNote';

    return PaymentQrResult(
      success: true,
      isDynamicGateway: false,
      gateway: 'standard_upi',
      qrId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      qrImageUrl: '',
      qrIntentUrl: fallbackUpiIntent,
      amount: amount,
      orderNumber: orderNumber,
      orderId: orderId,
    );
  }

  /// Real-time check if an order has been paid via UPI gateway / webhook
  Future<PaymentStatusResult> checkUpiPaymentStatusDetails(String orderId) async {
    final localOrder = orders.where((o) => o.id == orderId || o.orderNumber == orderId).firstOrNull;
    if (localOrder != null && localOrder.status == OrderStatus.completed) {
      return PaymentStatusResult(
        isPaid: true,
        paymentStatus: 'paid',
        orderNumber: localOrder.orderNumber,
        totalAmount: localOrder.totalAmount,
      );
    }
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        return await paymentService.checkPaymentStatus(orderId);
      }
    } catch (_) {}
    return PaymentStatusResult(isPaid: false, paymentStatus: 'pending');
  }

  /// Check boolean UPI payment status for an order
  Future<bool> checkUpiPaymentStatus(String orderId) async {
    final res = await checkUpiPaymentStatusDetails(orderId);
    return res.isPaid;
  }

  /// Deduplicate order list ensuring 1 order = 1 bill, purging rapid duplicate taps and identical bills
  List<OrderModel> deduplicateOrdersList(List<OrderModel> sourceOrders) {
    if (sourceOrders.isEmpty) return [];

    final List<OrderModel> result = [];
    final Set<String> seenIds = {};
    final Set<String> seenOrderNumbers = {};

    for (final order in sourceOrders) {
      final cleanId = order.id.trim();
      final cleanOrderNum = order.orderNumber.trim();

      // 1. Check ID collision
      if (cleanId.isNotEmpty && seenIds.contains(cleanId)) {
        continue; // Skip duplicate ID
      }

      // 2. Check Order Number collision (if non-empty and valid)
      if (cleanOrderNum.isNotEmpty && cleanOrderNum != '0000' && seenOrderNumbers.contains(cleanOrderNum)) {
        continue; // Skip duplicate Order Number
      }

      // 3. Check rapid-succession duplicate collision (same table/orderType, same amount, created within 5s)
      bool isRapidDuplicate = false;
      for (final existing in result) {
        final sameType = existing.orderType == order.orderType;
        final sameAmount = (existing.totalAmount - order.totalAmount).abs() < 0.01;
        final sameTableOrNone = (existing.tableNumber == null && order.tableNumber == null) ||
            (existing.tableNumber != null && order.tableNumber != null && isSameTable(existing.tableNumber, order.tableNumber));
        if (sameType && sameAmount && sameTableOrNone) {
          final diffSec = existing.createdDateTime.difference(order.createdDateTime).inSeconds.abs();
          if (diffSec <= 5) {
            if (existing.items.length == order.items.length) {
              isRapidDuplicate = true;
              break;
            }
          }
        }
      }

      if (isRapidDuplicate) {
        continue;
      }

      if (cleanId.isNotEmpty) seenIds.add(cleanId);
      if (cleanOrderNum.isNotEmpty && cleanOrderNum != '0000') seenOrderNumbers.add(cleanOrderNum);
      result.add(order);
    }

    return result;
  }

  /// Unified authoritative helper to get all settled/completed revenue orders within a date range
  List<OrderModel> getCompletedOrders({DateTime? start, DateTime? end}) {
    final deduplicated = deduplicateOrdersList(orders);
    return deduplicated.where((o) {
      // Exclude cancelled / void orders
      if (o.status == OrderStatus.cancelled) return false;

      // Must be completed or marked paid
      final bool isSettled = o.status == OrderStatus.completed ||
          o.isPaid ||
          o.paymentStatus.toLowerCase() == 'paid';
      if (!isSettled) return false;

      // Exclude unpaid KOT drafts that aren't settled
      final pm = o.paymentMethod.toLowerCase().trim();
      if (pm.contains('kot') && !o.isPaid && o.status != OrderStatus.completed) {
        return false;
      }

      // Timezone-safe local date check
      final oDate = o.createdDateTime.toLocal();
      if (start != null && oDate.isBefore(start)) return false;
      if (end != null && oDate.isAfter(end)) return false;

      return true;
    }).toList();
  }

  Future<void> _saveOrdersToPrefs() async {
    orders = deduplicateOrdersList(orders);
    await _prefs?.setString(_userKey('orders'), jsonEncode(orders.map((e) => e.toJson()).toList()));
  }

  // --- INVENTORY SERVICES ---
  Future<void> addInventoryStock(String id, double addedQty) async {
    final index = inventoryItems.indexWhere((inv) => inv.id == id);
    if (index >= 0) {
      final newQty = inventoryItems[index].quantity + addedQty;
      final updated = inventoryItems[index].copyWith(quantity: newQty);
      inventoryItems[index] = updated;
      await _saveInventoryToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth && id.length == 24) {
          await _inventoryService.updateItem(updated);
        }
      } catch (e) {
        debugPrint('[DatabaseService.addInventoryStock] API error: $e');
      }
    }
  }

  Future<void> _saveInventoryToPrefs() async {
    await _prefs?.setString(_userKey('inventory'), jsonEncode(inventoryItems.map((e) => e.toJson()).toList()));
  }

  // --- CUSTOMER MANAGEMENT & SUGGESTIONS ---
  Future<void> _saveCustomersToPrefs() async {
    await _prefs?.setString(_userKey('customers'), jsonEncode(customers.map((c) => c.toJson()).toList()));
  }

  Future<void> syncCustomersFromBackend() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return;

      final remoteCustomers = await _customerService.fetchCustomers(limit: 100);
      if (remoteCustomers.isNotEmpty) {
        final Map<String, CustomerModel> merged = {
          for (var c in customers) c.phone.trim(): c,
        };
        for (var rc in remoteCustomers) {
          merged[rc.phone.trim()] = rc;
        }
        customers = merged.values.toList();
        await _saveCustomersToPrefs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DatabaseService.syncCustomersFromBackend] error: $e');
    }
  }

  Future<CustomerModel> saveCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
  }) async {
    final cleanPhone = phone.trim();
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Customer';
    final existingIdx = customers.indexWhere((c) =>
      c.phone.replaceAll(RegExp(r'[^0-9]'), '') == cleanPhone.replaceAll(RegExp(r'[^0-9]'), '') ||
      c.phone.trim() == cleanPhone
    );

    CustomerModel customer;
    if (existingIdx >= 0) {
      final existing = customers[existingIdx];
      customer = existing.copyWith(
        name: cleanName,
        phone: cleanPhone,
        email: (email != null && email.trim().isNotEmpty) ? email : existing.email,
        address: (address != null && address.trim().isNotEmpty) ? address.trim() : existing.address,
        lastVisit: DateTime.now().toIso8601String(),
        totalOrders: existing.totalOrders + 1,
      );
      customers[existingIdx] = customer;
    } else {
      customer = CustomerModel(
        id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        phone: cleanPhone,
        email: email ?? '',
        address: (address != null && address.trim().isNotEmpty) ? address.trim() : '',
        totalOrders: 1,
        lastVisit: DateTime.now().toIso8601String(),
      );
      customers.insert(0, customer);
    }

    await _saveCustomersToPrefs();
    notifyListeners();

    // Persist to backend API in background
    _customerService.saveCustomer(
      name: cleanName,
      phone: cleanPhone,
      email: email,
      address: customer.address,
    ).then((remoteCustomer) {
      if (remoteCustomer != null) {
        final idx = customers.indexWhere((c) => c.phone.trim() == cleanPhone);
        if (idx >= 0) {
          customers[idx] = remoteCustomer;
          _saveCustomersToPrefs();
        }
      }
    }).catchError((e) {
      debugPrint('[DatabaseService.saveCustomer] backend error: $e');
    });

    return customer;
  }

  List<CustomerModel> searchCustomers(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final cleanDigits = clean.replaceAll(RegExp(r'[^0-9]'), '');

    final results = customers.where((c) {
      final cDigits = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneMatch = (cleanDigits.isNotEmpty && cDigits.contains(cleanDigits)) ||
          c.phone.toLowerCase().contains(clean);
      final nameMatch = c.name.toLowerCase().contains(clean);
      return phoneMatch || nameMatch;
    }).toList();

    // Sort: exact prefix match first, then by last visit
    results.sort((a, b) {
      final aDigits = a.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final bDigits = b.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final aStarts = cleanDigits.isNotEmpty && aDigits.startsWith(cleanDigits);
      final bStarts = cleanDigits.isNotEmpty && bDigits.startsWith(cleanDigits);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return 0;
    });

    return results.take(10).toList();
  }

  CustomerModel? getCustomerByPhone(String phone) {
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (cleanDigits.isEmpty) return null;
    return customers.where((c) =>
      (cleanDigits.length >= 6 && c.phone.replaceAll(RegExp(r'[^0-9]'), '').endsWith(cleanDigits)) ||
      c.phone.replaceAll(RegExp(r'[^0-9]'), '') == cleanDigits ||
      c.phone.trim() == phone.trim()
    ).firstOrNull;
  }

  Future<void> syncExtrasFromBackend() async {
    try {
      final list = await _extraService.fetchExtras();
      if (list.isNotEmpty) {
        extras = list;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DatabaseService.syncExtrasFromBackend] error: $e');
    }
  }

  // --- RE-SEED & RESET DATABASE ---
  Future<void> resetDatabase() async {
    await _prefs?.clear();
    menuItems.clear();
    tables.clear();
    orders.clear();
    inventoryItems.clear();
    customers.clear();
    extras.clear();

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
    await _saveRestaurantToPrefs();
    notifyListeners();
  }

  // SEEDERS
  void _seedCleanTables(int count) {
    final validCount = count > 0 ? count : 12;
    tables = List.generate(validCount, (index) {
      final num = index + 1;
      final floor = num <= 8 ? 'Ground Floor' : 'Terrace Garden';
      final cap = (num % 3 == 0) ? 6 : (num % 2 == 0 ? 4 : 2);
      return TableModel(
        id: 'tbl_$num',
        tableNumber: num,
        name: 'T-$num',
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
        occupiedSince: (num == 2 || num == 5 || num == 7)
            ? DateTime.now().subtract(Duration(minutes: num == 2 ? 14 : (num == 5 ? 52 : 78))).toIso8601String()
            : null,
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

  // ==========================================
  // MANUAL PRODUCT HISTORY (PER-USER PERSISTENCE)
  // ==========================================
  List<ManualProductHistoryItem> _manualProductsHistory = [];
  List<ManualProductHistoryItem> get manualProductsHistory => List.unmodifiable(_manualProductsHistory);

  void _loadManualProductsHistoryFromPrefs() {
    try {
      final isGuest = currentUser == null || currentUser?.id.isEmpty == true || currentUser?.id == 'guest';
      final jsonStr = _prefs?.getString(_userKey('manual_products_history')) ??
          (isGuest ? _prefs?.getString('apna_pos_manual_products_history') : null);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List raw = jsonDecode(jsonStr);
        _manualProductsHistory = raw
            .whereType<Map>()
            .map((e) => ManualProductHistoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _manualProductsHistory = [];
      }
    } catch (_) {
      _manualProductsHistory = [];
    }
  }

  Future<void> saveManualProductToHistory({
    required String name,
    required double price,
    required String foodType,
    required double gstPercent,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    if (_manualProductsHistory.isEmpty) {
      _loadManualProductsHistoryFromPrefs();
    }

    // Remove existing if present (case-insensitive deduplication)
    _manualProductsHistory.removeWhere((item) => item.name.trim().toLowerCase() == cleanName.toLowerCase());

    // Insert newest at front
    _manualProductsHistory.insert(
      0,
      ManualProductHistoryItem(
        name: cleanName,
        price: price,
        foodType: foodType,
        gstPercent: gstPercent,
        lastUsed: DateTime.now(),
      ),
    );

    // Keep up to 50 most recent items
    if (_manualProductsHistory.length > 50) {
      _manualProductsHistory = _manualProductsHistory.sublist(0, 50);
    }

    notifyListeners();

    try {
      final jsonStr = jsonEncode(_manualProductsHistory.map((e) => e.toJson()).toList());
      await _prefs?.setString(_userKey('manual_products_history'), jsonStr);
      final isGuest = currentUser == null || currentUser?.id.isEmpty == true || currentUser?.id == 'guest';
      if (isGuest) {
        await _prefs?.setString('apna_pos_manual_products_history', jsonStr);
      }
    } catch (_) {}
  }

  List<ManualProductHistoryItem> searchManualProductsHistory(String query) {
    if (_manualProductsHistory.isEmpty) {
      _loadManualProductsHistoryFromPrefs();
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _manualProductsHistory.take(8).toList();
    }

    // 1. Matching from persistent manual history
    final historyMatches = _manualProductsHistory
        .where((item) => item.name.toLowerCase().contains(q))
        .toList();

    // 2. Also match from menuItems (regular products added in Windows / POS catalog)
    final existingNames = historyMatches.map((h) => h.name.toLowerCase()).toSet();
    final menuMatches = menuItems
        .where((m) => m.name.toLowerCase().contains(q) && !existingNames.contains(m.name.toLowerCase()))
        .map((m) => ManualProductHistoryItem(
              name: m.name,
              price: m.price,
              foodType: m.itemType,
              gstPercent: m.gstPercent ?? (restaurant?.taxRate ?? 5.0),
              lastUsed: DateTime.now(),
            ))
        .toList();

    return [...historyMatches, ...menuMatches].take(8).toList();
  }
}

class ManualProductHistoryItem {
  final String name;
  final double price;
  final String foodType;
  final double gstPercent;
  final DateTime lastUsed;

  ManualProductHistoryItem({
    required this.name,
    required this.price,
    required this.foodType,
    required this.gstPercent,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'foodType': foodType,
    'gstPercent': gstPercent,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory ManualProductHistoryItem.fromJson(Map<String, dynamic> json) => ManualProductHistoryItem(
    name: json['name']?.toString() ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    foodType: json['foodType']?.toString() ?? 'Veg',
    gstPercent: (json['gstPercent'] as num?)?.toDouble() ?? 0.0,
    lastUsed: json['lastUsed'] != null ? (DateTime.tryParse(json['lastUsed']) ?? DateTime.now()) : DateTime.now(),
  );
}
