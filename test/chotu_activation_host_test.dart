import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/chotu_activation_service.dart';
import 'package:apna_pos/core/services/speech_recognition_service.dart';
import 'package:apna_pos/core/widgets/chotu_activation_host.dart';
import 'package:apna_pos/features/pos/widgets/chotu_voice_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/chotu_offline_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  final dio = ApiClient().dio;
  late HttpClientAdapter oldAdapter;
  late List<Interceptor> oldInterceptors;
  late ChotuOfflineAdapter adapter;
  var pending = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    oldAdapter = dio.httpClientAdapter;
    oldInterceptors = List.of(dio.interceptors);
    dio.interceptors.clear();
    dio.httpClientAdapter = adapter = ChotuOfflineAdapter();
    db.restaurant = RestaurantModel(
      id: 'host-test',
      name: 'Test',
      tagline: '',
      phone: '',
      address: '',
      cuisineType: 'Other',
    );
    db.currentUser = UserModel(
      id: 'test-owner',
      name: 'Owner',
      email: 'test@example.com',
      role: 'owner',
      pin: '',
      restaurantId: 'host-test',
    );
    pending = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => call.method == 'requestPermissions' ? {7: 1} : 1,
    );
    messenger.setMockMethodCallHandler(ChotuActivationService.channel, (
      call,
    ) async {
      if (call.method == 'consumeActivation') {
        final consumed = pending;
        pending = false;
        return consumed;
      }
      return null;
    });
  });
  tearDown(() {
    dio.httpClientAdapter = oldAdapter;
    dio.interceptors.addAll(oldInterceptors);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ChotuActivationService.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
    SpeechRecognitionService().reset();
    db.currentUser = null;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [chotuRouteObserver],
        home: const ChotuActivationHost(child: Scaffold(body: Text('Home'))),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'cold assistant request opens the gated voice overlay without an order command',
    (tester) async {
      pending = true;
      await open(tester);
      expect(find.byType(ChotuVoiceSheet), findsOneWidget);
      expect(SpeechRecognitionService().isListening, isTrue);
      expect(adapter.mutations, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'assistant entry cannot open Chotu for an unauthorized signed-in role',
    (tester) async {
      db.currentUser = UserModel(
        id: 'test-chef',
        name: 'Chef',
        email: 'chef@example.com',
        role: 'chef',
        pin: '',
        restaurantId: 'host-test',
        permissions: [],
      );
      pending = true;
      await open(tester);
      expect(find.byType(ChotuVoiceSheet), findsNothing);
      expect(SpeechRecognitionService().isListening, isFalse);
      expect(adapter.mutations, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('navigation suspends standby and app background disarms it', (
    tester,
  ) async {
    await open(tester);
    final arming = ChotuActivationService().arm();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await arming, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(SpeechRecognitionService().isListening, isTrue);
    Navigator.of(tester.element(find.text('Home'))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(SpeechRecognitionService().isListening, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(ChotuActivationService().isArmed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
}
