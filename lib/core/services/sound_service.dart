import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/pos/pos_register_screen.dart';

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
        await _ringtonePlayer?.setPlayerMode(PlayerMode.mediaPlayer);
      }

      await _buttonPlayer?.setReleaseMode(ReleaseMode.stop);
      await _keyPlayer?.setReleaseMode(ReleaseMode.stop);
      await _notificationPlayer?.setReleaseMode(ReleaseMode.stop);
      await _ringtonePlayer?.setReleaseMode(ReleaseMode.loop);

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _ringtonePlayer?.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gainTransientExclusive,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.duckOthers,
                AVAudioSessionOptions.defaultToSpeaker,
              },
            ),
          ),
        );
      }

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

  static const MethodChannel _nativeAlertChannel = MethodChannel('com.apnapos.app/order_alert');
  static int _lastBoostVolumeTime = 0;
  static int _lastBringToFrontTime = 0;

  /// Force phone hardware volume to maximum (alarm + media streams)
  static Future<void> boostHardwareVolume() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBoostVolumeTime < 5000) return;
    _lastBoostVolumeTime = now;

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _nativeAlertChannel.invokeMethod('setMaxVolume');
      }
    } catch (_) {}
  }

  /// Bring Android app / MainActivity directly to the front over any currently open app or lock screen
  static Future<void> bringAppToFront({String? payload, bool isUrgent = true}) async {
    if (PosRegisterScreen.isPosScreenActive) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldown = isUrgent ? 4000 : 8000;
    if (now - _lastBringToFrontTime < cooldown) return;
    _lastBringToFrontTime = now;

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _nativeAlertChannel.invokeMethod('bringToFront', {
          if (payload != null) ...{'payload': payload},
        });
      }
    } catch (_) {}
  }

  /// Toggle sound enabled/disabled setting
  static Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySoundEnabled, enabled);
    } catch (_) {}
  }

  static bool _isRingtonePlaying = false;
  static int _lastRingtonePlayTime = 0;
  bool _isStartingRingtone = false;

  /// Play incoming order receive ringtone continuously in a loop at full volume until accepted or rejected
  static void playOrderRingtone() {
    if (!soundEnabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Debounce to prevent overlapping triggers while ringtone is already looping
    if (_isRingtonePlaying && (now - _lastRingtonePlayTime < 3000)) {
      return;
    }
    _isRingtonePlaying = true;
    _lastRingtonePlayTime = now;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    // Force Android hardware alarm and media streams to 100% full volume
    boostHardwareVolume();

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
    if (_isStartingRingtone) return;
    _isStartingRingtone = true;
    try {
      if (_ringtonePlayer == null) {
        _ringtonePlayer = AudioPlayer();
        await _ringtonePlayer?.setPlayerMode(PlayerMode.mediaPlayer);
        await _ringtonePlayer?.setReleaseMode(ReleaseMode.loop);
      }
      await _ringtonePlayer?.stop();
      await _ringtonePlayer?.setVolume(1.0);
      await _ringtonePlayer?.play(AssetSource('sounds/order_recieve_ringtone.mp3'));
    } catch (_) {
      _playNotificationAsset();
    } finally {
      _isStartingRingtone = false;
    }
  }

  /// Stop incoming order ringtone
  static void stopOrderRingtone() async {
    _isRingtonePlaying = false;
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
