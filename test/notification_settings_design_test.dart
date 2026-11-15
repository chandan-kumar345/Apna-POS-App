import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:apna_pos/features/settings/notification_settings_screen.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/core/theme/glass_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['ALERTS_CAPTURE_DIR'];
  setUpAll(() async {
    if (directory != null) {
      await (FontLoader('SettingsReview')..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'notification settings header to footer and saved ringtone work at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: GlassTheme.themeData.copyWith(
                textTheme: GlassTheme.themeData.textTheme.apply(
                  fontFamily: directory == null ? null : 'SettingsReview',
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.2)),
                child: child!,
              ),
              home: const NotificationSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Notification settings'), findsOneWidget);
        final scaffold = find
            .descendant(
              of: find.byType(NotificationSettingsScreen),
              matching: find.byType(Scaffold),
            )
            .first;
        final theme = Theme.of(tester.element(scaffold));
        expect(theme.brightness, Brightness.light);
        final foreground = theme.colorScheme.onSurface.computeLuminance();
        expect(
          1.05 / (foreground + .05),
          greaterThan(7),
          reason:
              'Body text must remain readable under the actual dark app theme',
        );
        expect(find.text('Sounds & alerts'), findsOneWidget);
        expect(find.text('Synced'), findsNothing);
        expect(find.text('Save Settings').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (directory != null) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(directory).createSync(recursive: true);
            File(
              '$directory/notification-settings-${width.toInt()}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Kitchen Alert Chime'));
        await tester.tap(find.text('Kitchen Alert Chime'));
        await tester.pumpAndSettle();
        expect(SoundService.orderRingtoneUrl, 'sounds/Notification_sound.mp3');
        await tester.ensureVisible(find.text('Alert Preferences'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Save Settings').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
