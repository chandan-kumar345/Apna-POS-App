import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';

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
}
