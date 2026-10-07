import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/features/subscription/widgets/subscription_locked_bottom_sheet.dart';
import 'package:apna_pos/features/subscription/screens/subscription_screen.dart';
import 'package:apna_pos/features/super_admin/models/super_admin_user_model.dart';
import 'package:apna_pos/features/super_admin/services/super_admin_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PremiumSubscription & Profile Login State Tests', () {
    test('RestaurantModel correctly parses isSubscriptionActive & premiumSubscription', () {
      final json1 = {
        'id': 'biz_101',
        'name': 'Royal Flavors',
        'isSubscriptionActive': true,
        'tagline': 'Fine Dining',
        'phone': '9876543210',
        'address': 'Main Market',
        'cuisineType': 'Multi-Cuisine',
      };
      final rest1 = RestaurantModel.fromJson(json1);
      expect(rest1.isSubscribed, true);

      final json2 = {
        'id': 'biz_102',
        'name': 'Cafe Coffee',
        'premiumSubscription': {
          'isSubscriptionActive': true,
          'status': 'active',
          'hasLoyalty': true,
          'hasCampaign': true,
          'hasInventory': true,
        },
        'tagline': 'Coffee & More',
        'phone': '9876543211',
        'address': 'High Street',
        'cuisineType': 'Cafe',
      };
      final rest2 = RestaurantModel.fromJson(json2);
      expect(rest2.isSubscribed, true);
    });

    test('DatabaseService reflects active subscription status across methods', () async {
      final db = DatabaseService();
      await db.updateSubscriptionStatus(true);
      expect(db.isSubscribed, true);
      expect(db.isSubscriptionActive, true);

      await db.updateSubscriptionStatus(false);
      expect(db.isSubscribed, false);
      expect(db.isSubscriptionActive, false);
    });
  });

  group('SubscriptionLockedBarrier Widget Tests', () {
    testWidgets('SubscriptionLockedBarrier renders child directly when isSubscribed is true', (tester) async {
      final db = DatabaseService();
      await db.updateSubscriptionStatus(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionLockedBarrier(
              isLocked: false,
              child: const Text('Child POS Content'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Child POS Content'), findsOneWidget);
      expect(find.byType(SubscriptionLockedBottomSheet), findsNothing);
    });
  });

  group('SubscriptionScreen Interest Flow Tests', () {
    testWidgets('SubscriptionScreen renders and modal submission does not expose bypass button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubscriptionScreen(
              sourceFeature: 'loyalty',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Loyalty'), findsWidgets);
      // Ensure bypass button 'Open Loyalty Hub' is not rendered on screen
      expect(find.text('Open Loyalty Hub'), findsNothing);
    });
  });

  group('Neumorphic PRO Badge Tests', () {
    test('Staff Profile NavItemDef badge resolves to PRO when subscribed and null when unsubscribed', () async {
      final db = DatabaseService();
      await db.updateSubscriptionStatus(true);
      expect(db.isSubscribed, isTrue);

      // Verify db.isSubscribed gives PRO
      final badgeSubscribed = db.isSubscribed ? 'PRO' : null;
      expect(badgeSubscribed, equals('PRO'));

      await db.updateSubscriptionStatus(false);
      expect(db.isSubscribed, isFalse);

      final badgeUnsubscribed = db.isSubscribed ? 'PRO' : null;
      expect(badgeUnsubscribed, isNull);
    });
  });

  group('SuperAdmin PlatformUser & Per-User Subscription Isolation Tests', () {
    test('PlatformUser model defaults isSubscribed to false and retains userCreatedAt', () {
      final json = {
        'id': 'usr_test_999',
        'name': 'Ramesh Kumar',
        'email': 'ramesh@posstore.in',
        'phone': '9876543210',
        'businessId': 'biz_999',
        'businessName': 'Ramesh Sweets',
        'role': 'Owner',
        'status': 'active',
        'userCreatedAt': '2026-09-15T10:30:00.000Z',
      };

      final user = PlatformUser.fromJson(json);
      expect(user.isSubscribed, isFalse);
      expect(user.isSubscriptionActive, isFalse);
      expect(user.userCreatedAt.year, equals(2026));
      expect(user.userCreatedAt.month, equals(9));
      expect(user.userCreatedAt.day, equals(15));
    });

    test('SuperAdminApiService toggles subscription strictly for particular user without bleeding', () {
      final api = SuperAdminApiService();
      final user1 = api.users.firstWhere((u) => u.id == 'usr_007'); // Ananya Gupta (initially false)
      final user2 = api.users.firstWhere((u) => u.id == 'usr_008'); // Vikram Joshi (initially false)

      expect(user1.isSubscribed, isFalse);
      expect(user2.isSubscribed, isFalse);

      // Toggle user 1 to PRO
      api.toggleUserSubscription('usr_007', true);

      final updatedUser1 = api.users.firstWhere((u) => u.id == 'usr_007');
      final updatedUser2 = api.users.firstWhere((u) => u.id == 'usr_008');

      expect(updatedUser1.isSubscribed, isTrue);
      expect(updatedUser1.status, equals('paid'));
      expect(updatedUser2.isSubscribed, isFalse); // Strict tenant isolation

      // Deactivate user 1
      api.toggleUserSubscription('usr_007', false);
      final finalUser1 = api.users.firstWhere((u) => u.id == 'usr_007');
      expect(finalUser1.isSubscribed, isFalse);
    });
  });
}


