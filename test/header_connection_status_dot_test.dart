import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/core/widgets/connection_status_badge.dart';
import 'package:apna_pos/core/widgets/glass_company_name_badge.dart';
import 'package:apna_pos/core/widgets/pos_screen_top_header.dart';
import 'package:apna_pos/features/dashboard/main_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;

  setUp(() async {
    SoundService.soundEnabled = false;
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    await db.init();
    db.currentUser = UserModel(
      id: 'owner_01',
      name: 'Owner',
      email: 'owner@apnapos.com',
      phone: '9999999999',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_01',
      companyName: 'Pizza 47',
    );
    db.restaurant = RestaurantModel(
      id: 'rest_01',
      name: 'Pizza 47',
      companyName: 'Pizza 47',
      tagline: 'Hot & Fresh',
      phone: '9999999999',
      address: 'Main Street',
      cuisineType: 'Pizza',
      currencySymbol: '₹',
      taxRate: 5.0,
      billingType: 'GST',
    );
    NetworkService().isOnlineNotifier.value = true;
  });

  tearDown(() {
    NetworkService().isOnlineNotifier.value = true;
    NetworkService().dispose();
  });

  Color? readDotColor(WidgetTester tester) {
    final containerFinder = find.descendant(
      of: find.byType(ConnectionStatusDot),
      matching: find.byType(Container),
    );
    final container = tester.widget<Container>(containerFinder.first);
    final decoration = container.decoration as BoxDecoration?;
    return decoration?.color;
  }

  test('isPublicInternetUrl excludes localhost and private LAN ranges', () {
    expect(NetworkService.isPublicInternetUrl('http://127.0.0.1:5000/api/v1'), isFalse);
    expect(NetworkService.isPublicInternetUrl('http://localhost:5000/api/v1'), isFalse);
    expect(NetworkService.isPublicInternetUrl('http://10.0.2.2:5000/api/v1'), isFalse);
    expect(NetworkService.isPublicInternetUrl('http://172.16.2.4:5000/api/v1'), isFalse);
    expect(NetworkService.isPublicInternetUrl('http://192.168.1.10:5000/api/v1'), isFalse);
    expect(NetworkService.isPublicInternetUrl('https://apna-pos-app.onrender.com/api/v1'), isTrue);
  });

  testWidgets('GlassCompanyNameBadge renders green dot online and turns red offline', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFF031024),
            body: Center(
              child: GlassCompanyNameBadge(name: 'Pizza 47'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ConnectionStatusDot), findsOneWidget);
      expect(readDotColor(tester), const Color(0xFF22C55E));

      // Simulate internet loss
      NetworkService().isOnlineNotifier.value = false;
      await tester.pump();
      expect(readDotColor(tester), const Color(0xFFEF4444));

      // Simulate internet recovery
      NetworkService().isOnlineNotifier.value = true;
      await tester.pump();
      expect(readDotColor(tester), const Color(0xFF22C55E));
    });
  });

  testWidgets('PosScreenTopHeader removes standalone cloud button and keeps status dot in name pill', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(380, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFF031024),
            body: PosScreenTopHeader(storeTitle: 'Pizza 47'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GlassConnectionStatusBadge), findsNothing);
      expect(find.byType(GlassCompanyNameBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlassCompanyNameBadge),
          matching: find.byType(ConnectionStatusDot),
        ),
        findsOneWidget,
      );
      expect(readDotColor(tester), const Color(0xFF22C55E));

      NetworkService().isOnlineNotifier.value = false;
      await tester.pump();
      expect(readDotColor(tester), const Color(0xFFEF4444));
    });
  });

  testWidgets('MainLayout removes standalone cloud button and updates company badge dot color', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: MainLayout()));
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(GlassConnectionStatusBadge), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GlassCompanyNameBadge),
          matching: find.byType(ConnectionStatusDot),
        ),
        findsOneWidget,
      );
      expect(readDotColor(tester), const Color(0xFF22C55E));

      NetworkService().isOnlineNotifier.value = false;
      await tester.pump();
      expect(readDotColor(tester), const Color(0xFFEF4444));
    });
  });
}
