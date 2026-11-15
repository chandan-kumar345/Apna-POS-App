import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/customer_storefront_flow_models.dart';

typedef ConfirmTablePhone = Future<CustomerProfileModel> Function(String code);

class TablePhoneChallenge {
  final ConfirmTablePhone? confirm;
  final CustomerProfileModel? verified;

  const TablePhoneChallenge.code(this.confirm) : verified = null;
  const TablePhoneChallenge.instant(this.verified) : confirm = null;
}

/// Customer phone sign-in must never replace the merchant's Firebase session.
class TableQrPhoneAuth {
  static Future<FirebaseAuth>? _initializing;
  static Future<FirebaseAuth> _auth() => _initializing ??= _initialize()
      .catchError((Object error, StackTrace stack) {
        _initializing = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<FirebaseAuth> _initialize() async {
    const name = 'table-qr-customer';
    final matches = Firebase.apps.where((app) => app.name == name);
    final app = matches.isNotEmpty
        ? matches.first
        : await Firebase.initializeApp(
            name: name,
            options: Firebase.app().options,
          );
    return FirebaseAuth.instanceFor(app: app);
  }

  static CustomerProfileModel? _profile(User? user) {
    final phone = user?.phoneNumber;
    if (user == null || phone == null || phone.isEmpty) return null;
    return CustomerProfileModel(id: user.uid, phone: phone, name: 'Guest');
  }

  Future<CustomerProfileModel?> restore() async =>
      _profile((await _auth()).currentUser);

  Future<void> signOut() async => (await _auth()).signOut();

  Future<TablePhoneChallenge> send(String phone) async {
    final auth = await _auth();
    if (kIsWeb) {
      final challenge = await auth.signInWithPhoneNumber(phone);
      return TablePhoneChallenge.code(
        (code) async => _profile((await challenge.confirm(code)).user)!,
      );
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('SMS sign-in is unavailable on this device.');
    }
    final challenge = Completer<TablePhoneChallenge>();
    final result = challenge.future.timeout(const Duration(seconds: 60));
    void codeSent(String id) {
      if (challenge.isCompleted) return;
      challenge.complete(
        TablePhoneChallenge.code((code) async {
          final result = await auth.signInWithCredential(
            PhoneAuthProvider.credential(verificationId: id, smsCode: code),
          );
          return _profile(result.user)!;
        }),
      );
    }

    void failed(Object error, [StackTrace? stack]) {
      if (!challenge.isCompleted) challenge.completeError(error, stack);
    }

    unawaited(
      auth
          .verifyPhoneNumber(
            phoneNumber: phone,
            verificationCompleted: (credential) async {
              if (challenge.isCompleted) return;
              try {
                final credentialResult = await auth.signInWithCredential(
                  credential,
                );
                if (!challenge.isCompleted) {
                  challenge.complete(
                    TablePhoneChallenge.instant(
                      _profile(credentialResult.user)!,
                    ),
                  );
                }
              } catch (error, stack) {
                failed(error, stack);
              }
            },
            verificationFailed: failed,
            codeSent: (id, _) => codeSent(id),
            codeAutoRetrievalTimeout: codeSent,
          )
          .catchError(failed),
    );
    return result;
  }
}
