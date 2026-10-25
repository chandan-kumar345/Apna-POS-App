import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/coupon_model.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../../features/storefront/models/storefront_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  FirestoreService._internal() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        // Reset permission error flag when auth state changes (e.g. login/logout)
        _hasPermissionError = false;
      });
    } catch (_) {}
  }

  static bool _hasPermissionError = false;

  FirebaseFirestore? get _db {
    if (_hasPermissionError) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[FirestoreService] FirebaseFirestore initialization error: $e');
      return null;
    }
  }

  // Collections
  static const String usersCollection = 'users';
  static const String restaurantsCollection = 'restaurants';

  /// Save or update user profile in Firestore
  Future<void> saveUser(UserModel user) async {
    if (_hasPermissionError) return;
    try {
      final currentFbUser = FirebaseAuth.instance.currentUser;
      if (currentFbUser == null) {
        // Skip Firestore sync when not signed in with Firebase Auth
        return;
      }

      final db = _db;
      if (db == null) return;
      
      final data = user.toJson();
      // Sanitize large base64/blob strings to prevent Android SQLite CursorWindow (2MB) crash
      if (data['profilePhotoPath'] != null && (data['profilePhotoPath'] as String).length > 2000) {
        data['profilePhotoPath'] = '';
      }

      final docId = currentFbUser.uid.isNotEmpty
          ? currentFbUser.uid
          : (user.id.isNotEmpty ? user.id : 'usr_${DateTime.now().millisecondsSinceEpoch}');

      await db.collection(usersCollection).doc(docId).set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] User $docId successfully saved to Firestore');

      // If user.id is also set and different from docId, link it if permissible
      if (user.id.isNotEmpty && user.id != docId && !_hasPermissionError) {
        try {
          await db.collection(usersCollection).doc(user.id).set(
            data,
            SetOptions(merge: true),
          );
        } catch (_) {}
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('permission-denied') || errStr.contains('insufficient permissions')) {
        _hasPermissionError = true;
      }
      debugPrint('[FirestoreService] Firestore user sync paused (non-fatal): $e');
    }
  }

  /// Get user from Firestore
  Future<UserModel?> getUser(String userId) async {
    if (_hasPermissionError) return null;
    try {
      if (FirebaseAuth.instance.currentUser == null) return null;
      final db = _db;
      if (db == null) return null;
      final doc = await db.collection(usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('permission-denied') || errStr.contains('insufficient permissions')) {
        _hasPermissionError = true;
      }
      debugPrint('[FirestoreService] Error getting user from Firestore (non-fatal): $e');
      return null;
    }
  }

  /// Save or update restaurant details in Firestore
  Future<void> saveRestaurant(RestaurantModel restaurant) async {
    if (_hasPermissionError) return;
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      final db = _db;
      if (db == null) return;

      final data = restaurant.toJson();
      // Sanitize large base64/blob strings to prevent Android SQLite CursorWindow (2MB) crash
      if (data['logoUrl'] != null && (data['logoUrl'] as String).length > 2000) {
        data['logoUrl'] = '';
      }
      if (data['coverImageUrl'] != null && (data['coverImageUrl'] as String).length > 2000) {
        data['coverImageUrl'] = '';
      }

      await db.collection(restaurantsCollection).doc(restaurant.id).set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] Restaurant ${restaurant.id} saved to Firestore');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('permission-denied') || errStr.contains('insufficient permissions')) {
        _hasPermissionError = true;
      }
      debugPrint('[FirestoreService] Firestore restaurant sync paused (non-fatal): $e');
    }
  }

  /// Get restaurant from Firestore
  Future<RestaurantModel?> getRestaurant(String restaurantId) async {
    if (_hasPermissionError) return null;
    try {
      final db = _db;
      if (db == null) return null;
      final doc = await db.collection(restaurantsCollection).doc(restaurantId).get();
      if (doc.exists && doc.data() != null) {
        return RestaurantModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('permission-denied') || errStr.contains('insufficient permissions')) {
        _hasPermissionError = true;
      }
      debugPrint('[FirestoreService] Error getting restaurant from Firestore (non-fatal): $e');
      return null;
    }
  }

  /// Get restaurant by public storefront slug from Firestore
  Future<RestaurantModel?> getRestaurantBySlug(String slug) async {
    if (_hasPermissionError || slug.trim().isEmpty) return null;
    try {
      final db = _db;
      if (db == null) return null;

      final cleanSlug = slug.trim().toLowerCase();

      // 1. Try finding by 'slug' field
      try {
        final query = await db
            .collection(restaurantsCollection)
            .where('slug', isEqualTo: cleanSlug)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          data['id'] = query.docs.first.id;
          return RestaurantModel.fromJson(data);
        }
      } catch (_) {}

      // 2. Try direct doc ID match
      try {
        final doc = await db.collection(restaurantsCollection).doc(cleanSlug).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          data['id'] = doc.id;
          return RestaurantModel.fromJson(data);
        }
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('[FirestoreService] Error getting restaurant by slug (non-fatal): $e');
      return null;
    }
  }

  /// Save public menu items and storefront catalog to Firestore
  Future<void> saveStorefrontMenu({
    required String restaurantId,
    required List<MenuItemModel> items,
    required List<String> categories,
  }) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return;
    try {
      final db = _db;
      if (db == null) return;

      final storeDoc = db.collection('storefronts').doc(restaurantId);

      await storeDoc.set(
        {
          'restaurantId': restaurantId,
          'categories': categories,
          'itemCount': items.length,
          'updatedAt': FieldValue.serverTimestamp(),
          'items': items.map((e) => e.toJson()).toList(),
        },
        SetOptions(merge: true),
      );

      debugPrint('[FirestoreService] Storefront menu synced for $restaurantId (${items.length} items)');
    } catch (e) {
      debugPrint('[FirestoreService] Storefront menu sync notice: $e');
    }
  }

  /// Fetch public storefront menu items and categories
  Future<Map<String, dynamic>?> getStorefrontMenu(String restaurantId) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return null;
    try {
      final db = _db;
      if (db == null) return null;

      final doc = await db.collection('storefronts').doc(restaurantId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('[FirestoreService] Error getting storefront menu (non-fatal): $e');
      return null;
    }
  }

  /// Save promotional storefront banners to Firestore
  Future<void> saveStorefrontBanners({
    required String restaurantId,
    required List<StorefrontBanner> banners,
  }) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return;
    try {
      final db = _db;
      if (db == null) return;

      final storeDoc = db.collection('storefronts').doc(restaurantId);
      await storeDoc.set(
        {
          'banners': banners.map((b) => b.toJson()).toList(),
          'bannerCount': banners.length,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] Storefront banners synced for $restaurantId (${banners.length} banners)');
    } catch (e) {
      debugPrint('[FirestoreService] Storefront banners sync notice: $e');
    }
  }

  /// Fetch promotional storefront banners from Firestore
  Future<List<StorefrontBanner>> getStorefrontBanners(String restaurantId) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return [];
    try {
      final db = _db;
      if (db == null) return [];

      final doc = await db.collection('storefronts').doc(restaurantId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['banners'] is List) {
          return (data['banners'] as List)
              .map((e) => StorefrontBanner.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[FirestoreService] Error getting storefront banners: $e');
      return [];
    }
  }

  /// Save or update coupons list in Firestore for multi-device synchronization
  Future<void> saveCoupons({
    required String restaurantId,
    required List<CouponModel> coupons,
  }) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return;
    try {
      final db = _db;
      if (db == null) return;

      final storeDoc = db.collection('storefronts').doc(restaurantId);
      await storeDoc.set(
        {
          'coupons': coupons.map((c) => c.toJson()).toList(),
          'couponCount': coupons.length,
          'couponsUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] Synced ${coupons.length} coupons to Firestore for $restaurantId');
    } catch (e) {
      debugPrint('[FirestoreService] Error saving coupons to Firestore: $e');
    }
  }

  /// Get coupons list from Firestore for multi-device synchronization
  Future<List<CouponModel>> getCoupons(String restaurantId) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return [];
    try {
      final db = _db;
      if (db == null) return [];

      final doc = await db.collection('storefronts').doc(restaurantId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['coupons'] is List) {
          return (data['coupons'] as List)
              .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[FirestoreService] Error getting coupons from Firestore: $e');
      return [];
    }
  }

  /// Save public storefront settings (online status, theme color & gradient) to Firestore
  Future<void> saveStorefrontSettings({
    required String restaurantId,
    required bool isOnline,
    required int themeColorHex,
    int? themeColorEndHex,
  }) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return;
    try {
      final db = _db;
      if (db == null) return;

      final data = <String, dynamic>{
        'isOnline': isOnline,
        'isStorefrontOnline': isOnline,
        'themeColorHex': themeColorHex,
        'storefrontThemeColor': themeColorHex,
        if (themeColorEndHex != null) ...{
          'themeColorEndHex': themeColorEndHex,
          'storefrontThemeColorEnd': themeColorEndHex,
        },
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      };

      await db.collection('storefronts').doc(restaurantId).set(
        data,
        SetOptions(merge: true),
      );
      // Also sync to restaurants collection
      await db.collection(restaurantsCollection).doc(restaurantId).set(
        {
          'isStorefrontOnline': isOnline,
          'storefrontThemeColor': themeColorHex,
          if (themeColorEndHex != null) ...{
            'storefrontThemeColorEnd': themeColorEndHex,
          },
        },
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] Storefront settings synced to Firestore for $restaurantId');
    } catch (e) {
      debugPrint('[FirestoreService] Error saving storefront settings: $e');
    }
  }

  /// Fetch public storefront settings from Firestore
  Future<Map<String, dynamic>?> getStorefrontSettings(String restaurantId) async {
    if (_hasPermissionError || restaurantId.trim().isEmpty) return null;
    try {
      final db = _db;
      if (db == null) return null;

      final doc = await db.collection('storefronts').doc(restaurantId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('[FirestoreService] Error getting storefront settings: $e');
      return null;
    }
  }

  /// Submit customer online order to Firestore
  Future<bool> submitStorefrontOrder(OrderModel order, {required String restaurantId}) async {
    if (_hasPermissionError) return false;
    try {
      final db = _db;
      if (db == null) return false;

      final orderData = order.toJson();
      orderData['restaurantId'] = restaurantId;
      orderData['isOnlineOrder'] = true;
      orderData['source'] = 'online_storefront';
      orderData['submittedAt'] = FieldValue.serverTimestamp();

      await db.collection('orders').doc(order.id).set(orderData);
      debugPrint('[FirestoreService] Storefront order ${order.orderNumber} successfully posted');
      return true;
    } catch (e) {
      debugPrint('[FirestoreService] Error submitting storefront order: $e');
      return false;
    }
  }

  static const String whatsappSettingsCollection = 'whatsapp_settings';

  /// Save WhatsApp integration credentials to Firestore for cloud redundancy
  Future<void> saveWhatsAppSettings({
    required String businessOrUserId,
    required String phoneNumberId,
    required String phoneNumber,
    required String accessToken,
    String wabaId = '',
    bool enabled = true,
  }) async {
    if (_hasPermissionError || businessOrUserId.trim().isEmpty) return;
    try {
      final db = _db;
      if (db == null) return;

      final data = {
        'enabled': enabled,
        'phoneNumberId': phoneNumberId.trim(),
        'phoneNumber': phoneNumber.trim(),
        'wabaId': wabaId.trim(),
        'accessToken': accessToken.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await db.collection(whatsappSettingsCollection).doc(businessOrUserId.trim()).set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] WhatsApp settings saved to Firestore for $businessOrUserId');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('permission-denied') || errStr.contains('insufficient permissions')) {
        _hasPermissionError = true;
      }
      debugPrint('[FirestoreService] Error saving WhatsApp settings to Firestore (non-fatal): $e');
    }
  }

  /// Get WhatsApp integration credentials from Firestore
  Future<Map<String, dynamic>?> getWhatsAppSettings(String businessOrUserId) async {
    if (_hasPermissionError || businessOrUserId.trim().isEmpty) return null;
    try {
      final db = _db;
      if (db == null) return null;

      final doc = await db.collection(whatsappSettingsCollection).doc(businessOrUserId.trim()).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      return null;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('permission-denied') || errStr.contains('insufficient permissions')) {
        _hasPermissionError = true;
      }
      debugPrint('[FirestoreService] Error fetching WhatsApp settings from Firestore: $e');
      return null;
    }
  }

  static const String customersCollection = 'customers';

  /// Save or update customer profile in Firestore
  Future<void> saveCustomerProfile(Map<String, dynamic> customerData) async {
    if (_hasPermissionError) return;
    try {
      final db = _db;
      if (db == null) return;
      final id = customerData['id']?.toString() ?? '';
      if (id.isEmpty) return;

      final data = Map<String, dynamic>.from(customerData);
      data['updatedAt'] = FieldValue.serverTimestamp();

      await db.collection(customersCollection).doc(id).set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('[FirestoreService] Customer $id synced to Firestore');
    } catch (e) {
      debugPrint('[FirestoreService] Error saving customer profile: $e');
    }
  }

  /// Get customer profile from Firestore by ID or phone
  Future<Map<String, dynamic>?> getCustomerProfile(String customerIdOrPhone) async {
    if (_hasPermissionError || customerIdOrPhone.trim().isEmpty) return null;
    try {
      final db = _db;
      if (db == null) return null;

      final clean = customerIdOrPhone.trim();
      final doc = await db.collection(customersCollection).doc(clean).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }

      // Query by phone
      final query = await db
          .collection(customersCollection)
          .where('phone', isEqualTo: clean)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }

      return null;
    } catch (e) {
      debugPrint('[FirestoreService] Error getting customer profile: $e');
      return null;
    }
  }

  /// Stream order tracking updates from Firestore in real-time
  Stream<Map<String, dynamic>?> streamStorefrontOrder(String orderId) {
    if (_hasPermissionError || orderId.trim().isEmpty) {
      return Stream.value(null);
    }
    try {
      final db = _db;
      if (db == null) return Stream.value(null);
      return db.collection('orders').doc(orderId.trim()).snapshots().map((snap) {
        if (snap.exists && snap.data() != null) {
          return snap.data();
        }
        return null;
      });
    } catch (e) {
      debugPrint('[FirestoreService] Error streaming order $orderId: $e');
      return Stream.value(null);
    }
  }

  /// Update storefront order status (e.g. from POS merchant action or simulation)
  Future<void> updateStorefrontOrderStatus(String orderId, String status, int stepIndex) async {
    if (_hasPermissionError || orderId.trim().isEmpty) return;
    try {
      final db = _db;
      if (db == null) return;
      await db.collection('orders').doc(orderId.trim()).set({
        'status': status,
        'currentStepIndex': stepIndex,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error updating order status: $e');
    }
  }
}
