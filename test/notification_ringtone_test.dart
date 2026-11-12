import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/models/notification_setting_model.dart';
import 'package:apna_pos/core/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const audio = CustomRingtone(id: 'rt_1', name: 'Kitchen', url: '/uploads/kitchen.mp3');

  test('independent custom selections survive JSON round trip', () {
    const setting = NotificationSettingModel(
      orderRingtoneUrl: '/uploads/kitchen.mp3', orderRingtoneType: 'custom',
      customRingtones: [audio], orderVolume: 0.3, notificationVolume: 0.7,
    );
    final restored = NotificationSettingModel.fromJson(setting.toJson());
    expect(restored.orderRingtoneUrl, audio.url);
    expect(restored.orderRingtoneType, 'custom');
    expect(restored.notificationSoundType, 'default');
    expect(restored.customRingtones.single.id, audio.id);
    expect(restored.orderVolume, 0.3);
    expect(restored.notificationVolume, 0.7);
  });

  test('deleting a shared custom sound resets both complete selections', () {
    final setting = NotificationSettingModel(
      customRingtones: const [audio],
      orderRingtone: audio.url, orderRingtoneUrl: audio.url, orderRingtoneType: 'custom',
      notificationSound: audio.url, notificationSoundUrl: audio.url, notificationSoundType: 'custom',
    ).withoutRingtone(audio.id);
    const defaults = NotificationSettingModel();
    expect(setting.customRingtones, isEmpty);
    expect(setting.orderRingtone, defaults.orderRingtone);
    expect(setting.orderRingtoneUrl, defaults.orderRingtoneUrl);
    expect(setting.notificationSound, defaults.notificationSound);
    expect(setting.notificationSoundUrl, defaults.notificationSoundUrl);
  });

  test('removing an unused sound preserves active presets', () {
    const setting = NotificationSettingModel(
      customRingtones: [audio], orderRingtoneUrl: 'sounds/ios_click.wav', orderRingtoneType: 'preset',
    );
    expect(setting.withoutRingtone(audio.id).orderRingtoneUrl, setting.orderRingtoneUrl);
  });

  test('invalid persisted volumes are safe', () {
    final setting = NotificationSettingModel.fromJson({'orderVolume': 'NaN', 'notificationVolume': 8});
    expect(setting.orderVolume, 1);
    expect(setting.notificationVolume, 1);
  });

  test('sound selections, mute, and zero volume persist to playback preferences', () async {
    SharedPreferences.setMockInitialValues({});
    await SoundService().updateSoundPreferences(
      orderRingtoneUrl: audio.url, orderRingtoneType: 'custom',
      notificationSoundUrl: 'sounds/ios_click.wav', orderVolume: 0,
      notificationVolume: 0.4, soundEnabled: false,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pref_order_ringtone_url'), audio.url);
    expect(prefs.getDouble('pref_order_volume'), 0);
    expect(prefs.getDouble('pref_notif_volume'), 0.4);
    expect(prefs.getBool('sound_feedback_enabled'), false);
    expect(SoundService.orderVolume, 0);
  });

  test('cache filename is stable and distinguishes audio URLs', () {
    expect(SoundService.cacheFileName('https://example.com/a.mp3', 'mp3'),
        SoundService.cacheFileName('https://example.com/a.mp3', 'mp3'));
    expect(SoundService.cacheFileName('https://example.com/a.mp3', 'mp3'),
        isNot(SoundService.cacheFileName('https://example.com/b.mp3', 'mp3')));
  });

  test('each bundled preset points to a real playable source', () async {
    for (final asset in ['sounds/ios_click.wav', 'sounds/order_recieve_ringtone.mp3', 'sounds/Notification_sound.mp3']) {
      expect(File('assets/$asset').existsSync(), isTrue);
      expect(await SoundService.resolveAudioSource(asset), isA<AssetSource>());
    }
  });
}
