import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';

class FirestoreService {
  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // Collections
  static const String usersCollection = 'users';
  static const String restaurantsCollection = 'restaurants';

  /// Save or update user profile in Firestore
  Future<void> saveUser(UserModel user) async {
    try {
      final db = _db;
      if (db == null) return;
      
      final data = user.toJson();
      // Sanitize large base64/blob strings to prevent Android SQLite CursorWindow (2MB) crash
      if (data['profilePhotoPath'] != null && (data['profilePhotoPath'] as String).length > 2000) {
        data['profilePhotoPath'] = '';
      }

      await db.collection(usersCollection).doc(user.id).set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('User ${user.id} saved to Firestore');
    } catch (e) {
      debugPrint('Error saving user to Firestore (non-fatal): $e');
    }
  }

  /// Get user from Firestore
  Future<UserModel?> getUser(String userId) async {
    try {
      final db = _db;
      if (db == null) return null;
      final doc = await db.collection(usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user from Firestore: $e');
      return null;
    }
  }

  /// Save or update restaurant details in Firestore
  Future<void> saveRestaurant(RestaurantModel restaurant) async {
    try {
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
      debugPrint('Restaurant ${restaurant.id} saved to Firestore');
    } catch (e) {
      debugPrint('Error saving restaurant to Firestore (non-fatal): $e');
    }
  }

  /// Get restaurant from Firestore
  Future<RestaurantModel?> getRestaurant(String restaurantId) async {
    try {
      final db = _db;
      if (db == null) return null;
      final doc = await db.collection(restaurantsCollection).doc(restaurantId).get();
      if (doc.exists && doc.data() != null) {
        return RestaurantModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting restaurant from Firestore: $e');
      return null;
    }
  }
}
