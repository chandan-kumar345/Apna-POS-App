import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const String _prefKeySoundEnabled = 'sound_feedback_enabled';
  static bool soundEnabled = true;

  @visibleForTesting
  static VoidCallback? onButtonClickForTest;

  @visibleForTesting
  static void resetDebounceForTest() {
    _instance._lastButtonClickTime = 0;
  }

  AudioPlayer? _buttonPlayer;
  AudioPlayer? _keyPlayer;
  AudioPlayer? _notificationPlayer;
  AudioPlayer? _ringtonePlayer;

  bool _isInitialized = false;
  int _lastButtonClickTime = 0;
  int _lastKeyPressTime = 0;
  int _lastNotificationSoundTime = 0;
  int _lastOrderRingtoneTime = 0;

  /// Initialize sound service and preload audio sources lazily
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      soundEnabled = prefs.getBool(_prefKeySoundEnabled) ?? true;

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        _isInitialized = true;
        return;
      }

      _buttonPlayer = AudioPlayer();
      _keyPlayer = AudioPlayer();
      _notificationPlayer = AudioPlayer();
      _ringtonePlayer = AudioPlayer();

      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        await _buttonPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _keyPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _notificationPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _ringtonePlayer?.setPlayerMode(PlayerMode.lowLatency);
      }

      await _buttonPlayer?.setReleaseMode(ReleaseMode.stop);
      await _keyPlayer?.setReleaseMode(ReleaseMode.stop);
      await _notificationPlayer?.setReleaseMode(ReleaseMode.stop);
      await _ringtonePlayer?.setReleaseMode(ReleaseMode.stop);

      await _buttonPlayer?.setSource(AssetSource('sounds/ios_click.wav'));
      await _keyPlayer?.setSource(AssetSource('sounds/ios_keypress.wav'));
      await _notificationPlayer?.setSource(AssetSource('sounds/Notification_sound.mp3'));
      await _ringtonePlayer?.setSource(AssetSource('sounds/order_recieve_ringtone.mp3'));

      // Clean, crisp acoustic volumes
      await _buttonPlayer?.setVolume(0.85);
      await _keyPlayer?.setVolume(0.40);
      await _notificationPlayer?.setVolume(0.95);
      await _ringtonePlayer?.setVolume(1.0);

      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  /// Toggle sound enabled/disabled setting
  static Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySoundEnabled, enabled);
    } catch (_) {}
  }

  /// Play incoming order receive ringtone when an order arrives
  static void playOrderRingtone() {
    if (!soundEnabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastOrderRingtoneTime < 3000) {
      return;
    }
    _instance._lastOrderRingtoneTime = now;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    if (_instance._isInitialized) {
      _instance._playOrderRingtoneAsset();
    } else {
      _instance.init().then((_) => _instance._playOrderRingtoneAsset()).catchError((_) {});
    }
  }

  void _playOrderRingtoneAsset() async {
    try {
      await _ringtonePlayer?.stop();
      await _ringtonePlayer?.play(AssetSource('sounds/order_recieve_ringtone.mp3'));
    } catch (_) {
      _playNotificationAsset();
    }
  }

  /// Stop incoming order ringtone
  static void stopOrderRingtone() async {
    try {
      await _instance._ringtonePlayer?.stop();
    } catch (_) {}
  }

  /// Play real-time iPhone-style click sound when sound setting is on
  static void playIphoneClickSound() => playButtonClick();

  /// Play notification mp3 sound whenever a push or notification arrives
  static void playNotificationSound() {
    if (!soundEnabled) return;

    // Generous debounce (3500ms) to guarantee that a single incoming notification
    // cannot trigger multiple overlapping sounds from different listeners
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastNotificationSoundTime < 3500) {
      return;
    }
    _instance._lastNotificationSoundTime = now;

    // Trigger haptic notification feedback
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    if (_instance._isInitialized) {
      _instance._playNotificationAsset();
    } else {
      _instance.init().then((_) => _instance._playNotificationAsset()).catchError((_) {});
    }
  }

  void _playNotificationAsset() async {
    try {
      await _notificationPlayer?.stop();
      await _notificationPlayer?.play(AssetSource('sounds/Notification_sound.mp3'));
    } catch (_) {}
  }

  /// Play crisp real-time button click sound on interactive tap without double-trigger
  static void playButtonClick() {
    if (!soundEnabled) return;

    // Safe debounce (110ms) to ensure one click produces exactly one sound
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastButtonClickTime < 110) {
      return;
    }
    _instance._lastButtonClickTime = now;

    onButtonClickForTest?.call();

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    // 1. Hardware haptic feedback
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    // 2. Audio asset playback (fallback to native system sound while initializing)
    if (_instance._isInitialized) {
      _instance._playButtonAsset();
    } else {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      _instance.init().then((_) => _instance._playButtonAsset()).catchError((_) {});
    }
  }

  void _playButtonAsset() {
    try {
      _buttonPlayer?.play(AssetSource('sounds/ios_click.wav'));
    } catch (_) {}
  }

  /// Play light keypress sound on text field tap or typing with safe debouncing
  static void playKeyPress() {
    if (!soundEnabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastKeyPressTime < 150) {
      return;
    }
    _instance._lastKeyPressTime = now;

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    if (_instance._isInitialized) {
      _instance._playKeyAsset();
    } else {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      _instance.init().then((_) => _instance._playKeyAsset()).catchError((_) {});
    }
  }

  void _playKeyAsset() {
    try {
      _keyPlayer?.stop();
      _keyPlayer?.play(AssetSource('sounds/ios_keypress.wav'));
    } catch (_) {}
  }
}
