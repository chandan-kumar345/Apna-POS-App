import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/core/theme/glass_theme.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';
import 'package:apna_pos/features/storefront/services/storefront_service.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_menu_view.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_product_detail_sheet.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_checkout_flow_sheet.dart';

Map<String, dynamic> menuFixture({bool online = true}) => {
  'restaurant': {
    'id': 'river',
    'slug': 'river-kitchen',
    'name': 'River Kitchen',
    'tagline': 'Made fresh, every day',
    'cuisineType': 'Indian & Continental',
    'phone': '9876543210',
    'address': '12 River Road, Delhi',
    'currencySymbol': '₹',
    'services': ['Delivery', 'Takeaway'],
    'openingTime': '09:00 AM',
    'closingTime': '11:00 PM',
    'taxRate': 5,
    'tableCount': 0,
    'logoUrl': '',
    'isStorefrontOnline': online,
    'storefrontThemeColor': 0xFFE65100,
  },
  'isOnline': online,
  'themeColorHex': 0xFFE65100,
  'deliveryEta': '25–35 min',
  'categories': ['Paneer Pizza', 'Drinks'],
  'products': [
    {
      'id': 'p1',
      'name': 'Achari Paneer Pizza',
      'category': 'Paneer Pizza',
      'description': 'Paneer, onion, capsicum and tangy achari sauce',
      'price': 249,
      'image': 'assets/images/tpl_food_diwali_pizza.png',
      'foodType': 'veg',
    },
    {
      'id': 'p2',
      'name': 'Fresh Lime',
      'category': 'Drinks',
      'description': 'Fresh lime with sparkling water',
      'price': 79,
      'foodType': 'beverage',
    },
  ],
  'addons': [],
  'banners': [
    {
      'id': 'offer',
      'tag': 'LUNCH SPECIAL',
      'headline': 'COMBO DELIGHT BOX',
      'subtitle': 'Pizza + drink, made for your lunch break',
      'ctaText': 'EXPLORE MENU',
      'imageUrl': 'assets/images/tpl_food_bogo_pizza.png',
      'couponCode': 'LUNCH',
      'discountText': 'SAVE ₹100',
      'isActive': true,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (Platform.environment['STOREFRONT_CAPTURE_DIR'] != null &&
        font.existsSync()) {
      await (FontLoader('StorefrontReview')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  late List<Interceptor> originals;
  late Map<String, dynamic> response;
  Completer<void>? menuGate;
  bool notFound = false;
  final requests = <RequestOptions>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    response = menuFixture();
    menuGate = null;
    notFound = false;
    requests.clear();
    final dio = ApiClient().dio;
    originals = List.of(dio.interceptors);
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          if (notFound) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'message': 'Storefront business not found'},
                ),
              ),
            );
            return;
          }
          final branding = options.queryParameters['brandingOnly'] == 'true';
          if (!branding && menuGate != null) await menuGate!.future;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': branding
                    ? {'restaurant': response['restaurant']}
                    : response,
              },
            ),
          );
        },
      ),
    );
  });
  tearDown(() {
    ApiClient().dio.interceptors
      ..clear()
      ..addAll(originals);
    NetworkService().dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    String slug = 'river-kitchen',
    String? tableCode,
    GlobalKey? key,
    Size size = const Size(390, 844),
    bool merchantTheme = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final baseTheme = merchantTheme
        ? GlassTheme.themeData
        : ThemeData(useMaterial3: true);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(
              fontFamily: Platform.environment['STOREFRONT_CAPTURE_DIR'] != null
                  ? 'StorefrontReview'
                  : null,
            ),
          ),
          home: CustomerStorefrontScreen(slug: slug, tableCode: tableCode),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final dir = Platform.environment['STOREFRONT_CAPTURE_DIR'];
    if (dir == null) return;
    await tester.runAsync(() async {
      final context = key.currentContext!;
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/tpl_food_diwali_pizza.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/tpl_food_bogo_pizza.png'),
          context,
        ),
      ]);
    });
    await tester.pump();
    await tester.runAsync(() async {
      await Future.wait(
        tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => precacheImage(image.image, key.currentContext!)),
      );
    });
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('a new QR cannot inherit a cached table from another code', () async {
    response['table'] = {'isValid': true, 'tableCode': 'T01', 'isTableOrdering': true};
    final service = StorefrontService();
    final initial = await service.loadStorefront('qr-cache-fixture', tableCode: 'T01');
    expect(initial.tableInfo?.tableCode, 'T01');
    notFound = true;
    final other = await service.loadStorefront('qr-cache-fixture', tableCode: 'T02');
    expect(other.tableInfo?.tableCode, 'T02');
    expect(other.tableInfo?.isValid, isFalse);
    final same = await service.loadStorefront('qr-cache-fixture', tableCode: 'T01');
    expect(same.tableInfo?.isValid, isTrue);
    final normal = await service.loadStorefront('qr-cache-fixture');
    expect(normal.tableInfo, isNull);
  });

  testWidgets('a valid QR route opens the redesigned table home', (tester) async {
    response['table'] = {'isValid': true, 'tableCode': 'T01', 'isTableOrdering': true};
    final key = GlobalKey();
    await mount(tester, slug: 'qr-layout-fixture', tableCode: 'T01', key: key);
    expect(requests.any((r) => r.queryParameters['T'] == 'T01'), isTrue);
    expect(find.text('Welcome to Table T01'), findsOneWidget);
    await capture(tester, key, 'table-qr-01-home');
    await tester.tap(find.text('Explore menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ ADD').first);
    await tester.pumpAndSettle();
    await capture(tester, key, 'table-qr-02-menu');
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'table-qr-03-cart');
    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();
    expect(find.text('Continue as guest'), findsOneWidget);
    await capture(tester, key, 'table-qr-04-login');
    expect(tester.takeException(), isNull);
  });

  testWidgets('branding loads before menu and menu renders actual API data', (
    tester,
  ) async {
    final key = GlobalKey();
    menuGate = Completer<void>();
    await mount(tester, slug: 'brand-loading-test', key: key);
    expect(find.byType(StorefrontMenuLoading), findsOneWidget);
    expect(find.text('River Kitchen'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await capture(tester, key, 'restaurant-loading');
    menuGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StorefrontMenuView), findsOneWidget);
    expect(find.text('COMBO DELIGHT BOX'), findsOneWidget);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Achari Paneer Pizza'), findsOneWidget);
    expect(find.text('4.6'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'restaurant-menu-390');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'search, categories, product customization and cart work with API items',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'lime');
      await tester.pump();
      expect(find.text('Fresh Lime'), findsOneWidget);
      expect(find.text('Achari Paneer Pizza'), findsNothing);
      await tester.enterText(find.byType(TextField).first, '');
      tester.testTextInput.hide();
      await tester.tap(find.text('Paneer Pizza').first);
      await tester.pumpAndSettle();
      expect(find.text('Paneer Pizza (1)'), findsOneWidget);
      expect(find.text('Fresh Lime'), findsNothing);
      await tester.ensureVisible(find.text('+ ADD').first);
      await tester.tap(find.text('+ ADD').first);
      await tester.pumpAndSettle();
      expect(find.byType(StorefrontProductDetailSheet), findsOneWidget);
      await tester.tap(find.textContaining('Add to Cart').last);
      await tester.pumpAndSettle();
      expect(find.text('View Cart'), findsOneWidget);
      await tester.tap(find.text('View Cart'));
      await tester.pumpAndSettle();
      expect(find.byType(StorefrontCheckoutFlowSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'refresh keeps the menu visible and applies changed online status',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      menuGate = Completer<void>();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.byType(StorefrontMenuView), findsOneWidget);
      expect(find.byType(StorefrontMenuLoading), findsNothing);
      response = menuFixture(online: false);
      menuGate!.complete();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('+ ADD'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('unknown storefront shows retry instead of demo catalog', (
    tester,
  ) async {
    notFound = true;
    final key = GlobalKey();
    await mount(tester, slug: 'does-not-exist', key: key, merchantTheme: true);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Pizza 47'), findsNothing);
    expect(find.byType(StorefrontMenuView), findsNothing);
    final error = tester.widget<Text>(find.textContaining('We could not load'));
    expect(error.style?.color, const Color(0xFF334155));
    await capture(tester, key, 'restaurant-load-error');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compact phone layout has no overflow and uses API currency', (
    tester,
  ) async {
    response['restaurant']['currencySymbol'] = '\$';
    final key = GlobalKey();
    await mount(
      tester,
      slug: 'compact-store',
      key: key,
      size: const Size(320, 740),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('+ ADD').first);
    expect(find.text('\$249'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'restaurant-menu-320');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'public service refetches API data and never populates an empty catalog with demos',
    () async {
      response['products'] = [];
      response['categories'] = [];
      response['banners'] = [];
      final empty = await StorefrontService().loadStorefront('river-kitchen');
      expect(empty.menuItems, isEmpty);
      expect(empty.categories, ['All']);
      expect(empty.banners, isEmpty);
      expect(empty.rating, isNull);
      response = menuFixture();
      final next = await StorefrontService().loadStorefront('river-kitchen');
      expect(next.menuItems.length, 2);
      expect(
        requests
            .where((r) => r.queryParameters['brandingOnly'] != 'true')
            .length,
        2,
      );
    },
  );
}
