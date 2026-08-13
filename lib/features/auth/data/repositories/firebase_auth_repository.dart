import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' as fb_core;
import 'package:flutter/foundation.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../../../core/services/session_manager.dart';

/// Firebase implementation of [IAuthRepository] supporting Firebase Auth
/// for Email/Password, Phone OTP, and Session persistence.
class FirebaseAuthRepository implements IAuthRepository {
  final fb.FirebaseAuth? _customFirebaseAuth;
  final SessionManager _sessionManager;
  String? _verificationId;

  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    SessionManager? sessionManager,
  })  : _customFirebaseAuth = firebaseAuth,
        _sessionManager = sessionManager ?? SessionManager();

  fb.FirebaseAuth? get _auth {
    if (_customFirebaseAuth != null) return _customFirebaseAuth;
    try {
      if (fb_core.Firebase.apps.isNotEmpty) {
        return fb.FirebaseAuth.instance;
      }
    } catch (e) {
      debugPrint('FirebaseAuth instance resolution warning: $e');
    }
    return null;
  }

  @override
  Future<UserEntity> registerUser(UserEntity user) async {
    try {
      final auth = _auth;
      if (auth == null) {
        throw Exception('Firebase is not initialized on this platform.');
      }
      if (user.email.trim().isNotEmpty && user.password.trim().isNotEmpty) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: user.email.trim(),
          password: user.password.trim(),
        );

        if (credential.user != null) {
          await credential.user!.updateDisplayName(user.fullName);
        }

        final registeredUser = user.copyWith(
          id: credential.user?.uid.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        );

        if (registeredUser.id != null) {
          await saveSession(registeredUser.id!);
        }
        return registeredUser;
      } else {
        throw Exception('Email and Password are required for Firebase Registration.');
      }
    } catch (e) {
      debugPrint('FirebaseAuth registerUser error: $e');
      rethrow;
    }
  }

  @override
  Future<UserEntity?> login(String identifier, String password) async {
    try {
      final auth = _auth;
      if (auth == null) {
        throw Exception('Firebase Auth is not initialized on this device/platform.');
      }

      final cleanId = identifier.trim();
      final cleanPw = password.trim();

      if (!cleanId.contains('@')) {
        throw Exception('Phone login via password not supported in Firebase. Use verifyOtp.');
      }

      final credential = await auth.signInWithEmailAndPassword(
        email: cleanId,
        password: cleanPw,
      );

      final fbUser = credential.user;
      if (fbUser != null) {
        final userEntity = UserEntity(
          id: fbUser.uid.hashCode,
          fullName: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Firebase User',
          email: fbUser.email ?? cleanId,
          phoneNumber: fbUser.phoneNumber ?? '',
          password: cleanPw,
          createdAt: DateTime.now().toIso8601String(),
        );

        await saveSession(userEntity.id!);
        return userEntity;
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseAuth login error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    return false;
  }

  @override
  Future<bool> checkPhoneExists(String phoneNumber) async {
    return false;
  }

  @override
  Future<UserEntity?> getUserById(int id) async {
    final auth = _auth;
    final fbUser = auth?.currentUser;
    if (fbUser != null && fbUser.uid.hashCode == id) {
      return UserEntity(
        id: id,
        fullName: fbUser.displayName ?? 'Firebase User',
        email: fbUser.email ?? '',
        phoneNumber: fbUser.phoneNumber ?? '',
        password: '',
        createdAt: DateTime.now().toIso8601String(),
      );
    }
    return null;
  }

  @override
  Future<UserEntity?> getUserByEmailOrPhone(String identifier) async {
    final auth = _auth;
    final fbUser = auth?.currentUser;
    if (fbUser != null && (fbUser.email == identifier || fbUser.phoneNumber == identifier)) {
      return UserEntity(
        id: fbUser.uid.hashCode,
        fullName: fbUser.displayName ?? 'Firebase User',
        email: fbUser.email ?? '',
        phoneNumber: fbUser.phoneNumber ?? '',
        password: '',
        createdAt: DateTime.now().toIso8601String(),
      );
    }
    return null;
  }

  @override
  Future<bool> isSessionLoggedIn() async {
    final auth = _auth;
    final hasFbUser = auth?.currentUser != null;
    final hasSession = await _sessionManager.isLoggedIn();
    return hasFbUser || hasSession;
  }

  @override
  Future<int?> getLoggedInUserId() async {
    final auth = _auth;
    final fbUser = auth?.currentUser;
    if (fbUser != null) {
      return fbUser.uid.hashCode;
    }
    return await _sessionManager.getLoggedInUserId();
  }

  @override
  Future<void> saveSession(int userId) async {
    await _sessionManager.saveSession(userId);
  }

  @override
  Future<void> clearSession() async {
    final auth = _auth;
    if (auth != null) {
      await auth.signOut();
    }
    await _sessionManager.clearSession();
  }

  @override
  Future<bool> sendOtp(String recipient, {String purpose = 'login'}) async {
    try {
      final auth = _auth;
      if (auth == null) {
        debugPrint('FirebaseAuth sendOtp skipped: Firebase not initialized.');
        return false;
      }

      if (!recipient.startsWith('+')) {
        // Default to India country code +91 if missing prefix
        recipient = '+91$recipient';
      }

      await auth.verifyPhoneNumber(
        phoneNumber: recipient,
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          await auth.signInWithCredential(credential);
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          debugPrint('Firebase verifyPhoneNumber failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
      return true;
    } catch (e) {
      debugPrint('FirebaseAuth sendOtp error: $e');
      return false;
    }
  }

  @override
  Future<UserEntity?> verifyOtp(String recipient, String code, {String? fullName}) async {
    try {
      final auth = _auth;
      if (auth == null) {
        throw Exception('Firebase is not initialized on this platform.');
      }
      if (_verificationId == null) {
        throw Exception('Verification session expired. Please request a new OTP code.');
      }

      final credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final userCredential = await auth.signInWithCredential(credential);
      final fbUser = userCredential.user;

      if (fbUser != null) {
        final userEntity = UserEntity(
          id: fbUser.uid.hashCode,
          fullName: fullName ?? fbUser.displayName ?? 'Firebase Phone User',
          email: fbUser.email ?? 'user_$recipient@apnapos.com',
          phoneNumber: recipient,
          password: '1234',
          createdAt: DateTime.now().toIso8601String(),
        );

        await saveSession(userEntity.id!);
        return userEntity;
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseAuth verifyOtp error: $e');
      rethrow;
    }
  }
}
