import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/services/order_alert_permission_service.dart';
import 'package:apna_pos/features/settings/notification_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.apnapos.app/order_alert');
  final captureDirectory =
      Platform.environment['FULL_SCREEN_PERMISSION_CAPTURE_DIR'];
  bool granted = false;
  int requests = 0;
  Completer<bool>? settingsResult;
  setUpAll(() async {
    if (captureDirectory == null) return;
    await (FontLoader('PermissionReview')..addFont(
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
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    granted = false;
    requests = 0;
    settingsResult = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'checkOrderPermissions') {
            return {
              'overlayGranted': true,
              'batteryOptimizationIgnored': true,
              'notificationsEnabled': true,
              'fullScreenIntentRequired': true,
              'fullScreenIntentGranted': granted,
            };
          }
          if (call.method == 'requestFullScreenIntentPermission') {
            requests++;
            return settingsResult?.future ?? granted;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'settings retry waits for the system result and keeps a denial visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: captureDirectory == null ? null : 'PermissionReview',
            ),
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 25 && find.text('Allow').hitTestable().evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -220),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Full-screen order alerts'), findsOneWidget);
      expect(find.text('Allow').hitTestable(), findsOneWidget);
      if (captureDirectory != null) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(captureDirectory).createSync(recursive: true);
          File(
            '$captureDirectory/full-screen-order-permission-390.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      settingsResult = Completer<bool>();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(find.text('Opening…'), findsOneWidget);
      expect(requests, 1);
      settingsResult!.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Allow'), findsOneWidget);
      settingsResult = null;
      granted = true;
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Allow'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'full-screen access participates in critical Android alert readiness',
    (tester) async {
      await OrderAlertPermissionService.checkPermissions(forceRefresh: true);
      expect(
        await OrderAlertPermissionService.areCriticalPermissionsGranted(),
        isFalse,
      );
      granted = true;
      await OrderAlertPermissionService.checkPermissions(forceRefresh: true);
      expect(
        await OrderAlertPermissionService.areCriticalPermissionsGranted(),
        isTrue,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'non-Android platforms do not invoke Android full-screen settings',
    (tester) async {
      expect(
        await OrderAlertPermissionService.requestFullScreenIntentPermission(),
        isTrue,
      );
      expect(requests, 0);
      final permissions = await OrderAlertPermissionService.checkPermissions(
        forceRefresh: true,
      );
      expect(permissions['fullScreenIntentRequired'], isFalse);
      expect(permissions['fullScreenIntentGranted'], isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
