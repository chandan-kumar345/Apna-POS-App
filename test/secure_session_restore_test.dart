import 'dart:async';

import 'package:apna_pos/core/security/secure_storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late SharedPreferences prefs;
  late Completer<SharedPreferences> ready;
  late SecureStorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'SEC_KEY_AT_V1': 'saved-access',
      'SEC_KEY_RT_V1': 'saved-refresh',
      'SEC_KEY_UID_V1': 'saved-user',
      'SEC_KEY_DID_V1': 'saved-device',
      'SEC_KEY_BID_V1': 'saved-business',
    });
    prefs = await SharedPreferences.getInstance();
    ready = Completer<SharedPreferences>();
    storage = SecureStorageService.forTesting(
      storage: const FlutterSecureStorage(),
      preferences: () => ready.future,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('simultaneous startup reads all wait for the saved session', () async {
    final access = storage.getAccessToken();
    var refreshReturnedEarly = false;
    final refresh = storage.getRefreshToken().then((value) {
      refreshReturnedEarly = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(refreshReturnedEarly, isFalse);
    ready.complete(prefs);
    expect(await access, 'saved-access');
    expect(await refresh, 'saved-refresh');
    expect(await storage.getUserId(), 'saved-user');
  });

  test('saving business during startup cannot hide the saved tokens', () async {
    final save = storage.saveBusinessId('updated-business');
    final access = storage.getAccessToken();
    ready.complete(prefs);
    await save;
    expect(await access, 'saved-access');
    expect(await storage.getRefreshToken(), 'saved-refresh');
    expect(await storage.getBusinessId(), 'updated-business');
  });

  test('logout during a pending read cannot resurrect the session', () async {
    final load = storage.getAccessToken();
    final clear = storage.clearAll();
    ready.complete(prefs);
    await load;
    await clear;
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
    expect(prefs.getString('SEC_KEY_AT_V1'), isNull);
    expect(prefs.getString('SEC_KEY_RT_V1'), isNull);
  });

  test(
    'rotated refresh token reaches disk before a slow keystore write',
    () async {
      final nativeWrite = Completer<void>();
      final nativeStarted = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'write') {
              nativeStarted.complete();
              await nativeWrite.future;
            }
            return null;
          });
      ready.complete(prefs);
      final save = storage.saveRefreshToken('rotated-refresh');
      await nativeStarted.future;
      expect(prefs.getString('SEC_KEY_RT_V1'), 'rotated-refresh');
      nativeWrite.complete();
      await save;
    },
  );
}
