import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';

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
}
