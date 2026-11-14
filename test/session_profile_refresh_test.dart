import 'dart:convert';
import 'dart:typed_data';

import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProfileAdapter implements HttpClientAdapter {
  Map<String, dynamic> user = {};
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'data': {'user': user},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  final dio = ApiClient().dio;
  late HttpClientAdapter oldAdapter;
  late List<Interceptor> oldInterceptors;
  late _ProfileAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    oldAdapter = dio.httpClientAdapter;
    oldInterceptors = List.of(dio.interceptors);
    dio.interceptors.clear();
    adapter = _ProfileAdapter();
    dio.httpClientAdapter = adapter;
    db.restaurant = null;
    db.currentUser = UserModel(
      id: 'saved-owner',
      name: 'Owner',
      email: 'saved@example.test',
      role: 'Owner',
      pin: '',
      restaurantId: 'saved-business',
      onboardingCompleted: true,
      onboardingStep: 4,
    );
    adapter.user = {
      'id': 'saved-owner',
      'name': 'Owner',
      'email': 'saved@example.test',
      'role': 'Owner',
      'restaurantId': 'saved-business',
    };
  });

  tearDown(() {
    dio.httpClientAdapter = oldAdapter;
    dio.interceptors
      ..clear()
      ..addAll(oldInterceptors);
    db.currentUser = null;
    db.restaurant = null;
  });

  test(
    'refresh keeps completed setup when the profile omits setup fields',
    () async {
      final result = await AuthService().getMe();
      expect(db.currentUser!.onboardingCompleted, isTrue);
      expect(db.currentUser!.onboardingStep, 4);
      expect(result['user']['onboardingCompleted'], isTrue);
      expect(result['user']['onboardingStep'], 4);
    },
  );

  test('refresh preserves an unfinished saved setup step', () async {
    db.currentUser = db.currentUser!.copyWith(
      onboardingCompleted: false,
      onboardingStep: 2,
    );
    await AuthService().getMe();
    expect(db.currentUser!.onboardingCompleted, isFalse);
    expect(db.currentUser!.onboardingStep, 2);
  });

  test('a stale remote flag cannot undo completed local setup', () async {
    adapter.user['onboardingCompleted'] = false;
    await AuthService().getMe();
    expect(db.currentUser!.onboardingCompleted, isTrue);
  });

  test('setup progress is not copied into a different business', () async {
    adapter.user['restaurantId'] = 'other-business';
    await AuthService().getMe();
    expect(db.currentUser!.onboardingCompleted, isFalse);
    expect(db.currentUser!.onboardingStep, 0);
  });
}
