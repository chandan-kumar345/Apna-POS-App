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

      await _buttonPlayer.setSource(AssetSource('sounds/ios_click.wav'));
      await _keyPlayer.setSource(AssetSource('sounds/ios_keypress.wav'));

      // Ultra-light, soft volume for a gentle premium feel
      await _buttonPlayer.setVolume(0.35);
      await _keyPlayer.setVolume(0.25);

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  /// Toggle sound enabled/disabled setting
  static Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySoundEnabled, enabled);
  }

  /// Play light iOS button click sound on button/interactive tap (debounced to prevent double sound)
  static Future<void> playButtonClick() async {
    if (!soundEnabled) return;

    // Debounce within 100ms to guarantee exactly 1 sound per user click
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastButtonClickTime < 100) {
      return;
    }
    _instance._lastButtonClickTime = now;

    // Ultra-soft selection haptic
    HapticFeedback.selectionClick();

    try {
      if (_instance._isInitialized) {
        await _instance._buttonPlayer.stop();
        await _instance._buttonPlayer.play(AssetSource('sounds/ios_click.wav'));
      }
    } catch (_) {}
  }

  /// Play light iOS keypress sound on text field tap or typing (debounced)
  static Future<void> playKeyPress() async {
    if (!soundEnabled) return;

    // Rate-limiting for ultra-fast typing (debounce within 40ms)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastKeyPressTime < 40) {
      return;
    }
    _instance._lastKeyPressTime = now;

    // Subtle tactile feel
    HapticFeedback.selectionClick();

    try {
      if (_instance._isInitialized) {
        await _instance._keyPlayer.stop();
        await _instance._keyPlayer.play(AssetSource('sounds/ios_keypress.wav'));
      }
    } catch (_) {}
  }
}
