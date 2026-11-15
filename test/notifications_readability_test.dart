import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/security/secure_storage_service.dart';
import 'package:apna_pos/core/theme/glass_theme.dart';
import 'package:apna_pos/features/notifications/screens/notifications_screen.dart';
import 'package:apna_pos/features/notifications/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['ALERTS_CAPTURE_DIR'];
  late List<Interceptor> original;
  final requests = <RequestOptions>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    NotificationService(); // Own its app-lifetime polling timer outside widget fake time.
    if (directory != null) {
      await (FontLoader('InboxReview')..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await SecureStorageService().saveAccessToken('readability-test');
    requests.clear();
    original = List.of(ApiClient().dio.interceptors);
    ApiClient().dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final fixtures = [
              {
                'id': 'stock',
                'type': 'low_stock',
                'title': 'Stock running low',
                'message':
                    'Paneer stock is below your configured limit. Review inventory before accepting more orders.',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
              },
              {
                'id': 'system',
                'type': 'system',
                'title': 'Your settings are up to date',
                'message': 'Notification preferences were saved successfully.',
                'createdAt': DateTime.now().toIso8601String(),
                'isRead': false,
              },
            ];
            final type = options.queryParameters['type'];
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'notifications': fixtures
                        .where((item) => type == null || item['type'] == type)
                        .toList(),
                    'pagination': {'page': 1, 'totalPages': 1},
                    'unreadCount': 2,
                  },
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
      ..addAll(original);
  });
  tearDownAll(() {
    NotificationService().dispose();
  });
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'notification inbox stays readable under actual dark app theme at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: GlassTheme.themeData.copyWith(
                textTheme: GlassTheme.themeData.textTheme.apply(
                  fontFamily: directory == null ? null : 'InboxReview',
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.2)),
                child: child!,
              ),
              home: const NotificationsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Stock running low'), findsOneWidget);
        expect(find.text('Your settings are up to date'), findsOneWidget);
        final scaffold = find
            .descendant(
              of: find.byType(NotificationsScreen),
              matching: find.byType(Scaffold),
            )
            .first;
        expect(Theme.of(tester.element(scaffold)).brightness, Brightness.light);
        expect(tester.takeException(), isNull);
        if (directory != null) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(directory).createSync(recursive: true);
            File(
              '$directory/notifications-inbox-${width.toInt()}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Mark all as read'), findsOneWidget);
        await tester.tap(find.text('Mark all as read'));
        await tester.pumpAndSettle();
        expect(
          NotificationService().notifications.every((item) => item.isRead),
          isTrue,
        );
        await tester.ensureVisible(find.text('Inventory'));
        await tester.tap(find.text('Inventory'));
        await tester.pumpAndSettle();
        expect(find.text('Stock running low'), findsOneWidget);
        expect(find.text('Your settings are up to date'), findsNothing);
        expect(
          requests.any(
            (request) => request.queryParameters['type'] == 'low_stock',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
