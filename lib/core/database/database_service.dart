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
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

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
  ReportService get reportService => ReportService();
  DashboardService get dashboardService => DashboardService();
  
  ProductService get _productService => productService;
  OrderService get _orderService => orderService;
  TableService get _tableService => tableService;
  InventoryService get _inventoryService => inventoryService;
  CustomerService get _customerService => customerService;
  ExtraService get _extraService => extraService;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // In-Memory state for instant sync access
  UserModel? currentUser;
  List<UserModel> registeredUsers = [];
  RestaurantModel? restaurant;
  List<MenuItemModel> menuItems = [];
  List<String> categories = [];
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
        orders = raw.map((e) => OrderModel.fromJson(e)).toList();
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

    // Background sync with live backend if logged in
    syncWithBackend();
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
            );
            await _saveRestaurantToPrefs();
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

        final remoteCategories = await _productService.fetchCategories();
        if (remoteCategories.isNotEmpty) {
          categories = remoteCategories;
        } else {
          _syncCategoriesFromMenu();
        }
        await _saveCategoriesToPrefs();
      } catch (e) {
        debugPrint('[DatabaseService] sync products error: $e');
      }

      // 3. Fetch Live Tables from Backend
      try {
        final remoteTables = await _tableService.fetchTables();
        if (remoteTables.isNotEmpty) {
          tables = remoteTables;
          for (final t in remoteTables) {
            if (t.status == TableStatus.free) {
              _liveCartTotals.remove(t.name);
              _liveTableCarts.remove(t.name);
              _liveCartTotals.remove('T-${t.tableNumber}');
              _liveTableCarts.remove('T-${t.tableNumber}');
            } else if (t.activeOrderTotal > 0) {
              setLiveCartTotal(t.name, t.activeOrderTotal);
            }
          }
          await _saveTablesToPrefs();
        }
      } catch (e) {
        debugPrint('[DatabaseService] sync tables error: $e');
      }

      // 4. Fetch Live Orders from Backend
      try {
        final remoteOrders = await _orderService.fetchOrders();
        orders = remoteOrders;
        await _saveOrdersToPrefs();
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

    // Sync with Firestore
    if (currentUser != null) {
      await _firestoreService.saveUser(currentUser!);
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

    // Sync with Firestore
    if (currentUser != null) {
      await _firestoreService.saveUser(currentUser!);
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
      restaurant = restaurant!.copyWith(posViewMode: mode);
      await _saveRestaurantToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          final ApiClient client = ApiClient();
          await client.patch(ApiEndpoints.posSettings, data: {'posViewMode': mode});
        }
      } catch (e) {
        debugPrint('[DatabaseService.updatePosViewMode] API error: $e');
      }
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

    // 1. Ensure all categories exist locally and in DB
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

    // 3. Sync categories with remote backend
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        for (final item in items) {
          final cat = item.category.trim();
          if (cat.isNotEmpty) {
            try {
              await _productService.createCategory(cat);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService.importProductsFromCsv] Category sync warning: $e');
    }

    // 4. Sync products with remote backend via ProductService.bulkImport
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
  Future<void> addCategory(String categoryName) async {
    final name = categoryName.trim();
    if (name.isNotEmpty && !categories.contains(name)) {
      categories.add(name);
      await _saveCategoriesToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          await _productService.createCategory(name);
        }
      } catch (e) {
        debugPrint('[DatabaseService.addCategory] API error: $e');
      }
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

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          await _productService.updateCategory(oldName, updatedName);
        }
      } catch (e) {
        debugPrint('[DatabaseService.editCategory] API error: $e');
      }
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    categories.remove(categoryName);
    await _saveCategoriesToPrefs();
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        await _productService.deleteCategory(categoryName);
      }
    } catch (e) {
      debugPrint('[DatabaseService.deleteCategory] API error: $e');
    }
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

  // --- TABLE MANAGEMENT SERVICES ---
  Future<void> updateTableStatus(String tableId, TableStatus status, {String? orderId}) async {
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
      final nowStr = status == TableStatus.occupied ? DateTime.now().toString().substring(11, 16) : null;
      tables[index] = tbl.copyWith(
        status: status,
        currentOrderId: isFree ? null : (orderId ?? tbl.currentOrderId),
        occupiedSince: isFree ? null : (nowStr ?? tbl.occupiedSince),
        activeOrderTotal: isFree ? 0.0 : tbl.activeOrderTotal,
        activeItemCount: isFree ? 0 : tbl.activeItemCount,
      );
      await _saveTablesToPrefs();
      notifyListeners();

      try {
        final isAuth = await _authService.isAuthenticated();
        if (isAuth) {
          final targetApiId = tbl.id.isNotEmpty ? tbl.id : tblName;
          await _tableService.updateTableStatus(targetApiId, status, orderId: orderId);
        }
      } catch (e) {
        debugPrint('[DatabaseService.updateTableStatus] API error: $e');
      }
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
    final double taxRate = restaurant?.taxRate ?? 5.0;
    final double taxAmount = taxAmountOverride ?? ((subtotal - discountAmount).clamp(0.0, double.infinity) * (taxRate / 100.0));
    final double computedTotal = (subtotal - discountAmount + taxAmount + tipAmount + deliveryCharge + roundOff).clamp(0.0, double.infinity);
    final double finalTotalAmount = totalAmount ?? computedTotal;

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

    var newOrder = OrderModel(
      id: orderId,
      orderNumber: orderNum,
      tableNumber: tableNumber,
      orderType: orderType,
      status: status ?? OrderStatus.pending,
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
      createdAt: DateTime.now().toIso8601String(),
      customerName: customerName,
      customerPhone: customerPhone,
    );

    orders.insert(0, newOrder);
    await _saveOrdersToPrefs();

    // If customer phone is present, automatically save/update customer in CRM & local DB
    if (customerPhone != null && customerPhone.trim().isNotEmpty) {
      saveCustomer(
        name: (customerName != null && customerName.trim().isNotEmpty) ? customerName.trim() : 'Customer',
        phone: customerPhone.trim(),
        address: (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) ? deliveryAddress.trim() : null,
      );
    }

    // If table assigned, mark table as Occupied (pending) or Free (completed)
    if (tableNumber != null && tableNumber.isNotEmpty) {
      final tIndex = tables.indexWhere((t) => t.name == tableNumber || t.tableNumber.toString() == tableNumber);
      if (tIndex >= 0) {
        final targetStatus = (status == OrderStatus.completed) ? TableStatus.free : TableStatus.occupied;
        updateTableStatus(tables[tIndex].id, targetStatus, orderId: status == OrderStatus.completed ? null : orderId);
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
            orders[idx] = remoteOrder;
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
        paymentMethod: paymentMethod,
        roundOff: roundOff ?? orders[index].roundOff,
        totalAmount: totalAmount ?? orders[index].totalAmount,
      );

      final currentOrder = orders[index];
      final tNum = currentOrder.tableNumber;
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

  /// Real-time check if an order has been paid via UPI gateway / webhook
  Future<bool> checkUpiPaymentStatus(String orderId) async {
    final localOrder = orders.where((o) => o.id == orderId || o.orderNumber == orderId).firstOrNull;
    if (localOrder != null && localOrder.status == OrderStatus.completed) {
      return true;
    }
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        return await _orderService.checkUpiPaymentVerification(orderId);
      }
    } catch (_) {}
    return false;
  }

  Future<void> _saveOrdersToPrefs() async {
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
