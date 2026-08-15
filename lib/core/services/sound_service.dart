import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const String _prefKeySoundEnabled = 'sound_feedback_enabled';
  static bool soundEnabled = true;

  final AudioPlayer _buttonPlayer = AudioPlayer();
  final AudioPlayer _keyPlayer = AudioPlayer();
  
  bool _isInitialized = false;
  int _lastButtonClickTime = 0;
  int _lastKeyPressTime = 0;

  /// Initialize sound service and preload audio sources
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      soundEnabled = prefs.getBool(_prefKeySoundEnabled) ?? true;

      await _buttonPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _keyPlayer.setPlayerMode(PlayerMode.lowLatency);

      await _buttonPlayer.setReleaseMode(ReleaseMode.stop);
      await _keyPlayer.setReleaseMode(ReleaseMode.stop);

      await _buttonPlayer.setSource(AssetSource('sounds/ios_click.wav'));
      await _keyPlayer.setSource(AssetSource('sounds/ios_keypress.wav'));

      // Clean, crisp acoustic volume
      await _buttonPlayer.setVolume(0.40);
      await _keyPlayer.setVolume(0.30);

      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  /// Toggle sound enabled/disabled setting
  static Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySoundEnabled, enabled);
  }

  /// Play light button click sound on button/interactive tap immediately with 0 delay
  static void playButtonClick() {
    if (!soundEnabled) return;

    // Debounce within 60ms to avoid double sound
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastButtonClickTime < 60) {
      return;
    }
    _instance._lastButtonClickTime = now;

    // 1. Instant zero-latency native hardware sound & haptic feedback
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();

    // 2. Fast low-latency asset playback non-blockingly
    if (_instance._isInitialized) {
      _instance._playButtonAsset();
    }
  }

  void _playButtonAsset() async {
    try {
      await _buttonPlayer.stop();
      await _buttonPlayer.play(AssetSource('sounds/ios_click.wav'));
    } catch (_) {}
  }

  /// Play light keypress sound on text field tap or typing with zero latency
  static void playKeyPress() {
    if (!soundEnabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastKeyPressTime < 30) {
      return;
    }
    _instance._lastKeyPressTime = now;

    // Instant native hardware click
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();

    if (_instance._isInitialized) {
      _instance._playKeyAsset();
    }
  }

  void _playKeyAsset() async {
    try {
      await _keyPlayer.stop();
      await _keyPlayer.play(AssetSource('sounds/ios_keypress.wav'));
    } catch (_) {}
  }
}

