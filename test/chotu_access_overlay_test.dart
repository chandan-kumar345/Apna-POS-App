import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/chotu_service.dart';
import 'package:apna_pos/core/services/speech_recognition_service.dart';
import 'package:apna_pos/features/pos/widgets/chotu_voice_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChotuFixtureAdapter implements HttpClientAdapter {
  int healthStatus = 200;
  String code = 'CHOTU_AI_DISABLED';
  bool agentAvailable = true;
  int turnStatus = 200;
  int checks = 0;
  final turns = <Map<String, dynamic>>[];
  Completer<void>? holdHealth;
  Completer<void>? holdTurn;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final health = options.method == 'GET';
    if (health) {
      checks++;
      await holdHealth?.future;
    } else {
      turns.add(
        Map<String, dynamic>.from(
          options.data is String
              ? jsonDecode(options.data as String) as Map
              : options.data as Map,
        ),
      );
      await holdTurn?.future;
    }
    final status = health ? healthStatus : turnStatus;
    final body = status != 200
        ? {
            'error': {'code': code, 'message': 'Access denied'},
          }
        : {
            'data': health
                ? {
                    'geminiConfigured': false,
                    'automationAgent': {
                      'enabled': true,
                      'available': agentAvailable,
                    },
                  }
                : {'status': 'answered', 'chotuMessage': 'Table 5 is ready.'},
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = ChotuService();
  final speech = SpeechRecognitionService();
  final db = DatabaseService();
  final dio = ApiClient().dio;
  late HttpClientAdapter originalAdapter;
  late List<Interceptor> originalInterceptors;
  late ChotuFixtureAdapter adapter;
  var business = 0;

  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final player = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$player'),
            (_) async => null,
          );
        }
        return null;
      },
    );
    final fontDir = Platform.environment['CHOTU_CAPTURE_FONT_DIR'];
    if (fontDir == null) return;
    final loader = FontLoader('Roboto');
    for (final font in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('$fontDir/$font').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
    final fallback = FontLoader('Ahem')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('$fontDir/roboto-regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    await fallback.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('$fontDir/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => call.method == 'requestPermissions' ? {7: 1} : 1,
        );
    SharedPreferences.setMockInitialValues({});
    originalAdapter = dio.httpClientAdapter;
    originalInterceptors = List<Interceptor>.from(dio.interceptors);
    dio.interceptors.clear();
    adapter = ChotuFixtureAdapter();
    dio.httpClientAdapter = adapter;
    db.currentUser = null;
    db.restaurant = RestaurantModel(
      id: 'chotu-access-${business++}',
      name: 'Test Restaurant',
      tagline: '',
      phone: '',
      address: '',
      cuisineType: 'Indian',
      enableChotuVoice: true,
    );
    db.orders = [];
    db.tables = [];
    speech.reset();
    service.startConversation(tableNumber: '5');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
    speech.reset();
    dio.httpClientAdapter = originalAdapter;
    dio.interceptors.addAll(originalInterceptors);
  });

  test('healthy Python agent works without a configured Gemini key', () async {
    expect(await service.checkBackendHealth(), isTrue);
    expect(service.availability, ChotuAvailability.ready);
    expect(service.isBackendGeminiConfigured, isFalse);
    expect(service.accessMessage, isEmpty);
  });

  test('concurrent startup checks share one request', () async {
    adapter.holdHealth = Completer<void>();
    final first = service.checkBackendHealth();
    final second = service.checkBackendHealth();
    expect(identical(first, second), isTrue);
    adapter.holdHealth!.complete();
    expect(await first, isTrue);
    expect(adapter.checks, 1);
  });

  for (final entry in [
    (
      403,
      'CHOTU_AI_DISABLED',
      ChotuAvailability.disabled,
      'Chotu AI access is off for this business.',
    ),
    (
      403,
      'SUBSCRIPTION_REQUIRED',
      ChotuAvailability.subscriptionRequired,
      'An active subscription is required for Chotu AI.',
    ),
    (
      401,
      'UNAUTHORIZED',
      ChotuAvailability.signInRequired,
      'Sign in again to use Chotu AI.',
    ),
  ]) {
    test(
      'access error ${entry.$2} is visible and dispatches no order',
      () async {
        adapter.healthStatus = entry.$1;
        adapter.code = entry.$2;
        expect(await service.checkBackendHealth(), isFalse);
        expect(service.availability, entry.$3);
        expect(service.accessMessage, entry.$4);
        final result = await service.processAutomationTurn(
          speechText: 'add two naan',
        );
        expect(result?['status'], 'rejected');
        expect(adapter.turns, isEmpty);
        expect(db.orders, isEmpty);
      },
    );
  }

  test(
    'a failed startup can retry successfully in the same business',
    () async {
      adapter.agentAvailable = false;
      expect(await service.checkBackendHealth(), isFalse);
      adapter.agentAvailable = true;
      final result = await service.processAutomationTurn(
        speechText: 'show table 5',
      );
      expect(result?['status'], 'answered');
      expect(adapter.checks, 2);
      expect(adapter.turns, hasLength(1));
    },
  );

  test(
    'revoked access during a turn disables the agent without local execution',
    () async {
      await service.checkBackendHealth();
      adapter.turnStatus = 403;
      final result = await service.processAutomationTurn(
        speechText: 'add two naan',
      );
      expect(
        result?['chotuMessage'],
        'Chotu AI access is off for this business.',
      );
      expect(service.availability, ChotuAvailability.disabled);
      expect(db.orders, isEmpty);
    },
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChotuVoiceSheet(tableNumber: '5')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets(
    'transparent compact overlay waits for the mic button',
    (tester) async {
      await open(tester);
      expect(speech.isListening, isFalse);
      await tester.tap(find.byKey(const ValueKey('chotu-microphone')));
      await tester.pump();
      expect(speech.isListening, isTrue);
      expect(find.text('Chotu AI'), findsOneWidget);
      expect(find.text('Table 5'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Gemini'), findsNothing);
      final material = tester.widget<Material>(
        find.byKey(const ValueKey('chotu-transparent-overlay')),
      );
      expect(material.color, Colors.transparent);
      final panel = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('chotu-glass-panel')),
      );
      expect((panel.decoration as BoxDecoration).color!.a, lessThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('typed and finalized voice commands use the agent once each', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('chotu-order-input')),
      'show table 5',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(adapter.turns, hasLength(1));
    expect(adapter.turns.single['text'], 'show table 5');
    expect(find.text('Table 5 is ready.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chotu-microphone')));
    await tester.pump();
    speech.updateTranscription('table 5 ka total');
    speech.stopListening();
    speech.stopListening();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(adapter.turns, hasLength(2));
    expect(adapter.turns.last['text'], 'table 5 ka total');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'retry restores access without starting the microphone',
    (tester) async {
      adapter.healthStatus = 403;
      await open(tester);
      expect(
        find.text('Chotu AI access is off for this business.'),
        findsOneWidget,
      );
      expect(speech.isListening, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(adapter.turns, isEmpty);
      adapter.healthStatus = 200;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(speech.isListening, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('small display with keyboard and landscape do not overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    tester.view.physicalSize = const Size(320, 568);
    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(640, 360);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  if (Platform.environment['CHOTU_CAPTURE_DIR'] case final String directory) {
    testWidgets('capture the implemented glass overlay over a POS backdrop', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
            home: Stack(
              children: [
                Scaffold(
                  backgroundColor: const Color(0xFFEAF2FC),
                  appBar: AppBar(
                    title: const Text('Apna POS'),
                    backgroundColor: const Color(0xFFEAF2FC),
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Table 5',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const TextField(
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search products',
                          ),
                        ),
                        const SizedBox(height: 24),
                        for (final product in [
                          'Butter Naan',
                          'Paneer Tikka',
                          'Cold Coffee',
                        ])
                          Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.restaurant_rounded,
                                color: Color(0xFF225EC6),
                              ),
                              title: Text(product),
                              trailing: const Icon(Icons.add_circle_outline),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const ChotuVoiceSheet(tableNumber: '5'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(speech.isListening, isTrue);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final capture = await boundary.toImage(pixelRatio: 2);
        final data = await capture.toByteData(format: ui.ImageByteFormat.png);
        File('$directory/chotu-transparent.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data!.buffer.asUint8List());
        capture.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
