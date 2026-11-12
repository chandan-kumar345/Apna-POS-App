import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/features/auth/post_login_permission_observer.dart';
import 'package:apna_pos/features/notifications/services/notification_permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const orderChannel = MethodChannel('com.apnapos.app/order_alert');
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final events = <String>[];
  final requests = <List<int>>[];
  final statuses = <int, int>{};
  var defaultStatus = 0;
  var overlayGranted = false;
  var logOutDuringRequest = false;

  void logIn() {
    DatabaseService().currentUser = UserModel(
      id: 'permission-user',
      name: 'Permission User',
      email: 'permissions@example.test',
      phone: '',
      role: 'Owner',
      pin: '',
      restaurantId: '',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatabaseService().currentUser = null;
    events.clear();
    requests.clear();
    statuses.clear();
    defaultStatus = 0;
    overlayGranted = false;
    logOutDuringRequest = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      if (call.method == 'checkPermissionStatus') {
        return statuses[call.arguments] ?? defaultStatus;
      }
      if (call.method == 'requestPermissions') {
        final requested = List<int>.from(call.arguments as List);
        requests.add(requested);
        events.add(
          requested.contains(Permission.ignoreBatteryOptimizations.value)
              ? 'battery'
              : 'runtime',
        );
        if (logOutDuringRequest) DatabaseService().currentUser = null;
        return {for (final permission in requested) permission: 0};
      }
      throw PlatformException(
        code: 'unexpected-permission-call',
        message: call.method,
      );
    });
    messenger.setMockMethodCallHandler(orderChannel, (call) async {
      if (call.method == 'checkOrderPermissions') {
        return {
          'overlayGranted': overlayGranted,
          'batteryOptimizationIgnored': false,
          'notificationsEnabled': false,
        };
      }
      if (call.method == 'requestOverlayPermission') {
        events.add('overlay');
        return true;
      }
      throw PlatformException(
        code: 'unexpected-order-call',
        message: call.method,
      );
    });
    messenger.setMockMethodCallHandler(storageChannel, (_) async => null);
  });

  tearDown(() {
    DatabaseService().currentUser = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permissionsChannel, null);
    messenger.setMockMethodCallHandler(orderChannel, null);
    messenger.setMockMethodCallHandler(storageChannel, null);
  });

  Future<GlobalKey<NavigatorState>> mountApp(WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [PostLoginPermissionObserver()],
        home: const Scaffold(body: Text('Login')),
      ),
    );
    await tester.pumpAndSettle();
    return navigatorKey;
  }

  void navigate(GlobalKey<NavigatorState> key, String screen) {
    key.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(screen))),
    );
  }

  testWidgets('launch and logged-out navigation never request permissions', (
    tester,
  ) async {
    final navigator = await mountApp(tester);
    navigate(navigator, 'Sign up');
    await tester.pumpAndSettle();
    await NotificationPermissionHelper.requestAllAppPermissionsAfterLogin();

    expect(events, isEmpty);
    expect(requests, isEmpty);
    expect(find.byType(Dialog), findsNothing);
  }, variant: android);

  testWidgets(
    'login requests system permissions then opens overlay settings directly',
    (tester) async {
      final navigator = await mountApp(tester);
      logIn();
      navigate(navigator, 'POS');
      await tester.pumpAndSettle();

      expect(find.text('POS'), findsOneWidget);
      expect(events, ['runtime', 'battery', 'overlay']);
      expect(
        requests.first,
        containsAll([
          Permission.notification.value,
          Permission.camera.value,
          Permission.microphone.value,
          Permission.location.value,
          Permission.photos.value,
          Permission.bluetoothScan.value,
          Permission.bluetoothConnect.value,
        ]),
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Order Alert Permission'), findsNothing);
      expect(overlayGranted, isFalse);
    },
    variant: android,
  );

  testWidgets('native denials do not repeat on navigation or a later login', (
    tester,
  ) async {
    final navigator = await mountApp(tester);
    logIn();
    navigate(navigator, 'POS');
    await tester.pumpAndSettle();
    expect(events, ['runtime', 'battery', 'overlay']);

    navigate(navigator, 'Products');
    await tester.pumpAndSettle();
    DatabaseService().currentUser = null;
    logIn();
    navigate(navigator, 'POS again');
    await tester.pumpAndSettle();

    expect(events, ['runtime', 'battery', 'overlay']);
    expect(find.byType(Dialog), findsNothing);
  }, variant: android);

  testWidgets('restored sessions request only after leaving the splash route', (
    tester,
  ) async {
    logIn();
    final navigator = await mountApp(tester);
    expect(events, isEmpty);
    navigator.currentState!.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Restored POS')),
      ),
    );
    await tester.pumpAndSettle();

    expect(events, ['runtime', 'battery', 'overlay']);
    expect(find.text('Restored POS'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  }, variant: android);

  testWidgets('granted permissions never open another permission screen', (
    tester,
  ) async {
    defaultStatus = 1;
    overlayGranted = true;
    logIn();
    await NotificationPermissionHelper.requestAllAppPermissionsAfterLogin();

    expect(events, isEmpty);
    expect(requests, isEmpty);
  }, variant: android);

  testWidgets(
    'overlapping requests share a single system permission sequence',
    (tester) async {
      logIn();
      await Future.wait([
        NotificationPermissionHelper.requestAllAppPermissionsAfterLogin(),
        NotificationPermissionHelper.requestAllAppPermissionsAfterLogin(),
      ]);

      expect(events, ['runtime', 'battery', 'overlay']);
    },
    variant: android,
  );

  testWidgets('permanently denied permissions are not requested again', (
    tester,
  ) async {
    statuses[Permission.camera.value] = 4;
    statuses[Permission.microphone.value] = 4;
    logIn();
    await NotificationPermissionHelper.requestAllAppPermissionsAfterLogin();

    expect(requests.first, isNot(contains(Permission.camera.value)));
    expect(requests.first, isNot(contains(Permission.microphone.value)));
    expect(events.last, 'overlay');
  }, variant: android);

  testWidgets(
    'logout while answering a prompt prevents the remaining requests',
    (tester) async {
      logIn();
      logOutDuringRequest = true;
      await NotificationPermissionHelper.requestAllAppPermissionsAfterLogin();

      expect(events, ['runtime']);
      expect(DatabaseService().currentUser, isNull);
    },
    variant: android,
  );

  testWidgets(
    'iOS requests its permissions without opening Android special settings',
    (tester) async {
      logIn();
      await NotificationPermissionHelper.requestAllAppPermissionsAfterLogin();

      expect(events, ['runtime']);
      expect(
        requests.single,
        containsAll([
          Permission.notification.value,
          Permission.camera.value,
          Permission.microphone.value,
          Permission.location.value,
          Permission.photos.value,
          Permission.speech.value,
          Permission.bluetooth.value,
        ]),
      );
      expect(requests.single, isNot(contains(Permission.bluetoothScan.value)));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
