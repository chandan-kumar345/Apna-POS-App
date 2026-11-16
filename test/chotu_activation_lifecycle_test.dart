import 'dart:async';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/chotu_activation_service.dart';
import 'package:apna_pos/core/services/speech_recognition_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _HealthAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    '{"data":{"automationAgent":{"enabled":true,"available":true}}}',
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final activation = ChotuActivationService();
  final speech = SpeechRecognitionService();
  final dio = ApiClient().dio;
  late HttpClientAdapter oldAdapter;
  late List<Interceptor> oldInterceptors;
  var activations = 0;
  setUp(() {
    oldAdapter = dio.httpClientAdapter;
    oldInterceptors = List.of(dio.interceptors);
    dio.interceptors.clear();
    dio.httpClientAdapter = _HealthAdapter();
    DatabaseService().restaurant = RestaurantModel(
      id: 'wake-test',
      name: 'Test',
      tagline: '',
      phone: '',
      address: '',
      cuisineType: 'Other',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => call.method == 'requestPermissions' ? {7: 1} : 1,
        );
    activations = 0;
    activation.attach(() => activations++);
    activation.suspend(false);
  });
  tearDown(() {
    activation.detach();
    speech.reset();
    dio.httpClientAdapter = oldAdapter;
    dio.interceptors.addAll(oldInterceptors);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
  });

  Future<void> arm(WidgetTester tester) async {
    final pending = activation.arm();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await pending, isTrue);
  }

  testWidgets('only final exact wake phrase activates and consumes standby', (
    tester,
  ) async {
    await arm(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(speech.isListening, isTrue);
    speech.updateTranscription('Hello Chotu');
    expect(activations, 0);
    speech.stopListening();
    expect(activations, 1);
    expect(activation.isArmed, isFalse);
    speech.stopListening();
    expect(activations, 1);
  });

  testWidgets('background suspension stops capture and ignores late words', (
    tester,
  ) async {
    await arm(tester);
    await tester.pump(const Duration(seconds: 1));
    activation.suspend(true);
    expect(speech.isListening, isFalse);
    speech.updateTranscription('Hello Chotu');
    speech.stopListening();
    expect(activations, 0);
    activation.disarm();
    activation.suspend(false);
    await tester.pump(const Duration(seconds: 1));
    expect(speech.isListening, isFalse);
  });

  testWidgets('standby expires and cannot execute an ambient order', (
    tester,
  ) async {
    await arm(tester);
    await tester.pump(const Duration(seconds: 1));
    speech.updateTranscription('Hello Chotu settle cash');
    speech.stopListening();
    expect(activations, 0);
    await tester.pump(const Duration(minutes: 2));
    expect(activation.isArmed, isFalse);
    expect(speech.isListening, isFalse);
  });

  testWidgets('disarm cancels a pending health/permission startup', (
    tester,
  ) async {
    final pending = activation.arm();
    activation.disarm();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await pending, isFalse);
    expect(activation.isArmed, isFalse);
    expect(speech.isListening, isFalse);
  });
}
