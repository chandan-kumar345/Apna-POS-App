import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../network/api_endpoints.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const String _prefKeySoundEnabled = 'sound_feedback_enabled';
  static bool soundEnabled = true;

  // Custom Ringtone and Sound configuration
  static String orderRingtoneUrl = 'sounds/order_recieve_ringtone.mp3';
  static String orderRingtoneName = 'Default Apna POS (Looping Alarm)';
  static String orderRingtoneType = 'default';
  static double orderVolume = 1.0;

  static String notificationSoundUrl = 'sounds/Notification_sound.mp3';
  static String notificationSoundName = 'Default Apna POS (Chime)';
  static String notificationSoundType = 'default';
  static double notificationVolume = 1.0;

  static String? currentlyPreviewingSource;
  static bool isPreviewPlaying = false;

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
  AudioPlayer? _previewPlayer;
  StreamSubscription? _previewCompleteSub;

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

      orderRingtoneUrl = prefs.getString('pref_order_ringtone_url') ?? 'sounds/order_recieve_ringtone.mp3';
      orderRingtoneName = prefs.getString('pref_order_ringtone_name') ?? 'Default Apna POS (Looping Alarm)';
      orderRingtoneType = prefs.getString('pref_order_ringtone_type') ?? 'default';
      orderVolume = prefs.getDouble('pref_order_volume') ?? 1.0;

      notificationSoundUrl = prefs.getString('pref_notif_sound_url') ?? 'sounds/Notification_sound.mp3';
      notificationSoundName = prefs.getString('pref_notif_sound_name') ?? 'Default Apna POS (Chime)';
      notificationSoundType = prefs.getString('pref_notif_sound_type') ?? 'default';
      notificationVolume = prefs.getDouble('pref_notif_volume') ?? 1.0;

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        _isInitialized = true;
        return;
      }

      _buttonPlayer = AudioPlayer();
      _keyPlayer = AudioPlayer();
      _notificationPlayer = AudioPlayer();
      _ringtonePlayer = AudioPlayer();
      _previewPlayer = AudioPlayer();

      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        await _buttonPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _keyPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _notificationPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _ringtonePlayer?.setPlayerMode(PlayerMode.mediaPlayer);
        await _previewPlayer?.setPlayerMode(PlayerMode.mediaPlayer);
      }

      await _buttonPlayer?.setReleaseMode(ReleaseMode.stop);
      await _keyPlayer?.setReleaseMode(ReleaseMode.stop);
      await _notificationPlayer?.setReleaseMode(ReleaseMode.stop);
      await _ringtonePlayer?.setReleaseMode(ReleaseMode.loop);
      await _previewPlayer?.setReleaseMode(ReleaseMode.stop);

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
      await _notificationPlayer?.setVolume(notificationVolume);
      await _ringtonePlayer?.setVolume(orderVolume);

      _isInitialized = true;

      // Prefetch and cache custom ringtone & notification sounds in background for 0ms offline playback
      if (!kIsWeb) {
        if (orderRingtoneUrl.isNotEmpty) {
          prefetchAndCacheAudio(orderRingtoneUrl);
        }
        if (notificationSoundUrl.isNotEmpty) {
          prefetchAndCacheAudio(notificationSoundUrl);
        }
      }
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

  static final Map<String, String> _memoryAudioCache = {};

  /// Directly associate a local file path with a URL in the cache map
  static void cacheLocalFile(String rawUrl, String filePath) {
    if (kIsWeb) return;
    try {
      final resolved = ApiEndpoints.resolveMediaUrl(rawUrl);
      _memoryAudioCache[rawUrl] = filePath;
      _memoryAudioCache[resolved] = filePath;
      debugPrint('[SoundService] Registered local file in audio cache: $rawUrl -> $filePath');
    } catch (_) {}
  }

  /// Pre-cache a remote audio file to local storage so it plays instantly with 0ms latency and 100% offline
  static Future<String?> prefetchAndCacheAudio(String? rawUrl) async {
    if (kIsWeb || rawUrl == null || rawUrl.trim().isEmpty) return null;
    final clean = rawUrl.trim();
    if (clean.startsWith('sounds/') || clean.startsWith('assets/sounds/')) {
      return null;
    }
    if (File(clean).existsSync()) {
      return clean;
    }

    final resolved = ApiEndpoints.resolveMediaUrl(clean);
    if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
      return null;
    }

    if (_memoryAudioCache.containsKey(resolved)) {
      final cached = _memoryAudioCache[resolved]!;
      if (File(cached).existsSync() && File(cached).lengthSync() > 100) {
        return cached;
      }
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/ringtones');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final uri = Uri.parse(resolved);
      final rawExt = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last.toLowerCase() : 'mp3';
      final ext = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'flac'].contains(rawExt) ? rawExt : 'mp3';
      final fileName = 'ringtone_${resolved.hashCode.abs()}.$ext';
      final targetFile = File('${dir.path}/$fileName');

      if (targetFile.existsSync() && targetFile.lengthSync() > 100) {
        _memoryAudioCache[resolved] = targetFile.path;
        return targetFile.path;
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 && response.bodyBytes.length > 100) {
        await targetFile.writeAsBytes(response.bodyBytes);
        _memoryAudioCache[resolved] = targetFile.path;
        debugPrint('[SoundService] Cached custom audio locally: ${targetFile.path} (${response.bodyBytes.length} bytes)');
        return targetFile.path;
      }
    } catch (e) {
      debugPrint('[SoundService] Prefetch audio failed for "$resolved": $e');
    }
    return null;
  }

  /// Resolve raw source (asset, local file, or remote URL) to an audioplayers Source
  static Future<Source> resolveAudioSource(String? rawSource, {bool isOrder = true}) async {
    final defaultAsset = isOrder
        ? 'sounds/order_recieve_ringtone.mp3'
        : 'sounds/Notification_sound.mp3';

    if (rawSource == null || rawSource.trim().isEmpty) {
      return AssetSource(defaultAsset);
    }

    var clean = rawSource.trim();

    // 1. Asset path
    if (clean.startsWith('sounds/') || clean.startsWith('assets/sounds/')) {
      return AssetSource(clean.replaceFirst(RegExp(r'^assets/'), ''));
    }

    // 2. Direct local file on disk
    if (!kIsWeb) {
      try {
        final f = File(clean);
        if (f.existsSync()) {
          return DeviceFileSource(f.path);
        }
      } catch (_) {}
    }

    // 3. Resolve URL via ApiEndpoints (handles relative /uploads/..., localhost rewrites, etc.)
    final resolved = ApiEndpoints.resolveMediaUrl(clean);

    // If resolved to a local file
    if (!kIsWeb) {
      try {
        final f = File(resolved);
        if (f.existsSync()) {
          return DeviceFileSource(f.path);
        }
      } catch (_) {}
    }

    // 4. Remote HTTP/HTTPS URL
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      if (!kIsWeb) {
        // Check local cache
        final cached = await prefetchAndCacheAudio(resolved);
        if (cached != null && File(cached).existsSync()) {
          return DeviceFileSource(cached);
        }
      }
      return UrlSource(resolved);
    }

    return AssetSource(defaultAsset);
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
      await _ringtonePlayer?.setVolume(orderVolume);

      final source = await resolveAudioSource(orderRingtoneUrl, isOrder: true);
      debugPrint('[SoundService] 🔔 Playing active order ringtone: $orderRingtoneUrl -> $source at volume $orderVolume');
      await _ringtonePlayer?.play(source);
    } catch (e) {
      debugPrint('[SoundService] Failed playing custom order ringtone: $e. Falling back to default.');
      try {
        await _ringtonePlayer?.play(AssetSource('sounds/order_recieve_ringtone.mp3'));
      } catch (_) {
        _playNotificationAsset();
      }
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

  /// Start previewing an audio ringtone or notification sound
  static Future<void> startPreview({
    required String source,
    required bool isLooping,
    double volume = 1.0,
    VoidCallback? onComplete,
  }) async {
    try {
      await stopPreview();
      final player = _instance._previewPlayer ??= AudioPlayer();
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(isLooping ? ReleaseMode.loop : ReleaseMode.stop);
      await player.setVolume(volume);

      _instance._previewCompleteSub?.cancel();
      _instance._previewCompleteSub = player.onPlayerComplete.listen((_) {
        isPreviewPlaying = false;
        currentlyPreviewingSource = null;
        _instance._previewCompleteSub?.cancel();
        _instance._previewCompleteSub = null;
        onComplete?.call();
      });

      final audioSource = await resolveAudioSource(source, isOrder: isLooping);
      await player.play(audioSource);
      isPreviewPlaying = true;
      currentlyPreviewingSource = source;
    } catch (e) {
      debugPrint('[SoundService] Preview error: $e');
      isPreviewPlaying = false;
      currentlyPreviewingSource = null;
    }
  }

  /// Stop current sound preview
  static Future<void> stopPreview() async {
    try {
      isPreviewPlaying = false;
      currentlyPreviewingSource = null;
      _instance._previewCompleteSub?.cancel();
      _instance._previewCompleteSub = null;
      await _instance._previewPlayer?.stop();
    } catch (_) {}
  }

  /// Synchronize sound preferences locally and update runtime state
  Future<void> updateSoundPreferences({
    String? orderRingtoneUrl,
    String? orderRingtoneName,
    String? orderRingtoneType,
    double? orderVolume,
    String? notificationSoundUrl,
    String? notificationSoundName,
    String? notificationSoundType,
    double? notificationVolume,
    bool? soundEnabled,
    String? orderUrl,
    String? orderName,
    String? orderType,
    double? orderVol,
    String? notifUrl,
    String? notifName,
    String? notifType,
    double? notifVol,
    bool? isSoundOn,
  }) async {
    final effectiveOrderUrl = orderRingtoneUrl ?? orderUrl;
    final effectiveOrderName = orderRingtoneName ?? orderName;
    final effectiveOrderType = orderRingtoneType ?? orderType;
    final effectiveOrderVol = orderVolume ?? orderVol;

    final effectiveNotifUrl = notificationSoundUrl ?? notifUrl;
    final effectiveNotifName = notificationSoundName ?? notifName;
    final effectiveNotifType = notificationSoundType ?? notifType;
    final effectiveNotifVol = notificationVolume ?? notifVol;

    final effectiveSoundEnabled = soundEnabled ?? isSoundOn;

    if (effectiveOrderUrl != null) SoundService.orderRingtoneUrl = effectiveOrderUrl;
    if (effectiveOrderName != null) SoundService.orderRingtoneName = effectiveOrderName;
    if (effectiveOrderType != null) SoundService.orderRingtoneType = effectiveOrderType;
    if (effectiveOrderVol != null) SoundService.orderVolume = effectiveOrderVol;

    if (effectiveNotifUrl != null) SoundService.notificationSoundUrl = effectiveNotifUrl;
    if (effectiveNotifName != null) SoundService.notificationSoundName = effectiveNotifName;
    if (effectiveNotifType != null) SoundService.notificationSoundType = effectiveNotifType;
    if (effectiveNotifVol != null) SoundService.notificationVolume = effectiveNotifVol;

    if (effectiveSoundEnabled != null) SoundService.soundEnabled = effectiveSoundEnabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (effectiveOrderUrl != null) await prefs.setString('pref_order_ringtone_url', effectiveOrderUrl);
      if (effectiveOrderName != null) await prefs.setString('pref_order_ringtone_name', effectiveOrderName);
      if (effectiveOrderType != null) await prefs.setString('pref_order_ringtone_type', effectiveOrderType);
      if (effectiveOrderVol != null) await prefs.setDouble('pref_order_volume', effectiveOrderVol);

      if (effectiveNotifUrl != null) await prefs.setString('pref_notif_sound_url', effectiveNotifUrl);
      if (effectiveNotifName != null) await prefs.setString('pref_notif_sound_name', effectiveNotifName);
      if (effectiveNotifType != null) await prefs.setString('pref_notif_sound_type', effectiveNotifType);
      if (effectiveNotifVol != null) await prefs.setDouble('pref_notif_volume', effectiveNotifVol);

      if (effectiveSoundEnabled != null) await prefs.setBool(_prefKeySoundEnabled, effectiveSoundEnabled);

      if (SoundService.orderVolume > 0 && _ringtonePlayer != null) {
        await _ringtonePlayer?.setVolume(SoundService.orderVolume);
      }
      if (SoundService.notificationVolume > 0 && _notificationPlayer != null) {
        await _notificationPlayer?.setVolume(SoundService.notificationVolume);
      }

      // Prefetch audio in background so when an order or alert arrives it plays instantly
      if (!kIsWeb) {
        if (effectiveOrderUrl != null && effectiveOrderUrl.isNotEmpty) {
          prefetchAndCacheAudio(effectiveOrderUrl);
        }
        if (effectiveNotifUrl != null && effectiveNotifUrl.isNotEmpty) {
          prefetchAndCacheAudio(effectiveNotifUrl);
        }
      }
    } catch (_) {}
  }

  /// Static helper for backwards compatibility
  static Future<void> syncSoundPreferences({
    String? orderRingtoneUrl,
    String? orderRingtoneName,
    String? orderRingtoneType,
    double? orderVolume,
    String? notificationSoundUrl,
    String? notificationSoundName,
    String? notificationSoundType,
    double? notificationVolume,
    bool? soundEnabled,
    String? orderUrl,
    String? orderName,
    String? orderType,
    double? orderVol,
    String? notifUrl,
    String? notifName,
    String? notifType,
    double? notifVol,
    bool? isSoundOn,
  }) => _instance.updateSoundPreferences(
    orderRingtoneUrl: orderRingtoneUrl ?? orderUrl,
    orderRingtoneName: orderRingtoneName ?? orderName,
    orderRingtoneType: orderRingtoneType ?? orderType,
    orderVolume: orderVolume ?? orderVol,
    notificationSoundUrl: notificationSoundUrl ?? notifUrl,
    notificationSoundName: notificationSoundName ?? notifName,
    notificationSoundType: notificationSoundType ?? notifType,
    notificationVolume: notificationVolume ?? notifVol,
    soundEnabled: soundEnabled ?? isSoundOn,
  );

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
      if (_notificationPlayer == null) {
        _notificationPlayer = AudioPlayer();
        await _notificationPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _notificationPlayer?.setReleaseMode(ReleaseMode.stop);
      }
      await _notificationPlayer?.stop();
      await _notificationPlayer?.setVolume(notificationVolume);

      final source = await resolveAudioSource(notificationSoundUrl, isOrder: false);
      debugPrint('[SoundService] 🔔 Playing active notification alert sound: $notificationSoundUrl -> $source at volume $notificationVolume');
      await _notificationPlayer?.play(source);
    } catch (e) {
      debugPrint('[SoundService] Failed playing custom notification sound: $e. Falling back to default.');
      try {
        await _notificationPlayer?.play(AssetSource('sounds/Notification_sound.mp3'));
      } catch (_) {}
    }
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
