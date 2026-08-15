import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/restaurant_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  static const String usersCollection = 'users';
  static const String restaurantsCollection = 'restaurants';

  /// Save or update user profile in Firestore
  Future<void> saveUser(UserModel user) async {
    try {
      await _db.collection(usersCollection).doc(user.id).set(
        user.toJson(),
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
      final doc = await _db.collection(usersCollection).doc(userId).get();
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
      await _db.collection(restaurantsCollection).doc(restaurant.id).set(
        restaurant.toJson(),
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
      final doc = await _db.collection(restaurantsCollection).doc(restaurantId).get();
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
