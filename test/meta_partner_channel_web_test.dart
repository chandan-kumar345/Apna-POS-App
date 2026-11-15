import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/services/meta_partner_service.dart';
import 'package:apna_pos/features/settings/meta_partner_channel_screen.dart';
import 'package:apna_pos/core/theme/glass_theme.dart';

class FakeMetaService extends MetaPartnerService {
  FakeMetaService() : super.forTesting();
  bool fail = false, registered = false;
  int registrations = 0;
  @override
  Future<MetaPartnerStatus?> getStatus() async {
    if (fail) throw Exception('Server unavailable. Try again.');
    return MetaPartnerStatus(
      partnerStatus: 'SETUP_REQUIRED',
      phoneNumberId: '555001',
      phoneNumber: '+91 98765 43210',
      wabaId: '444001',
      verifiedName: 'Test Cafe',
      metaPartnerVerified: true,
      pinRegistered: registered,
    );
  }

  @override
  Future<List<MetaChannelItem>> getChannels() async => [
    MetaChannelItem(
      channelId: 'line-1',
      name: 'Test Cafe',
      phoneNumber: '+91 98765 43210',
      phoneNumberId: '555001',
      wabaId: '444001',
      pinRegistered: registered,
    ),
  ];
  @override
  Future<List<MetaTemplateItem>> getTemplates() async => [
    const MetaTemplateItem(
      name: 'order_confirmation',
      category: 'UTILITY',
      displayName: 'Order confirmation',
      description: '',
      status: 'NOT_SUBMITTED',
      language: 'en_US',
    ),
  ];
  @override
  Future<bool> registerPin({
    required String channelId,
    required String pin,
  }) async {
    registrations++;
    registered = true;
    return true;
  }
}

void main() {
  final capture = Platform.environment['META_CAPTURE_DIR'];
  setUpAll(() async {
    if (capture == null) return;
    await (FontLoader('MetaReview')..addFont(
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
  });

  Future<GlobalKey> show(
    WidgetTester tester,
    double width,
    FakeMetaService service, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
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
              fontFamily: capture == null ? null : 'MetaReview',
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: MetaPartnerChannelScreen(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> screenshot(
    WidgetTester tester,
    GlobalKey key,
    String name,
  ) async {
    if (capture == null) return;
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(capture).createSync(recursive: true);
      File('$capture/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> reveal(WidgetTester tester, String label) async {
    for (var attempt = 0; attempt < 25; attempt++) {
      if (find.text(label).hitTestable().evaluate().isNotEmpty) return;
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
    }
    expect(find.text(label).hitTestable(), findsOneWidget);
  }

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('responsive setup and actionable registration at $width', (
      tester,
    ) async {
      final service = FakeMetaService();
      final key = await show(tester, width, service);
      expect(find.text('WhatsApp Business'), findsOneWidget);
      expect(find.text('Finish setup'), findsOneWidget);
      expect(find.text('Official Tech Provider'), findsNothing);
      expect(find.text('98.6%'), findsNothing);
      expect(tester.takeException(), isNull);
      await screenshot(tester, key, 'meta-setup-${width.toInt()}');
      await reveal(tester, 'Register');
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(service.registrations, 0);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(service.registrations, 1);
      expect(find.text('Number registered.'), findsOneWidget);
      expect(find.text('Register'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('offline state is explicit and retry restores the connection', (
    tester,
  ) async {
    final service = FakeMetaService()..fail = true;
    await show(tester, 390, service);
    expect(find.text('Connection unavailable'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Finish setup'), findsOneWidget);
  });
  testWidgets('template suggestions are not shown as approved', (tester) async {
    final key = await show(tester, 390, FakeMetaService());
    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    expect(find.text('en_US · not submitted'), findsOneWidget);
    expect(find.text('APPROVED'), findsNothing);
    await screenshot(tester, key, 'meta-templates-390');
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text remains usable on a narrow phone', (tester) async {
    await show(tester, 320, FakeMetaService(), scale: 1.4);
    await reveal(tester, 'Enable');
    await tester.pumpAndSettle();
    expect(find.text('Enable').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('missing status fields never imply verification or readiness', () {
    final status = MetaPartnerStatus.fromJson({});
    expect(status.metaPartnerVerified, isFalse);
    expect(status.canSend, isFalse);
    expect(status.qualityRating, 'UNKNOWN');
  });

  testWidgets(
    'light setup and PIN dialog remain readable under the real dark app theme',
    (tester) async {
      final key = await show(tester, 390, FakeMetaService());
      expect(
        Theme.of(tester.element(find.text('WhatsApp Business'))).brightness,
        Brightness.light,
      );
      await reveal(tester, 'Register');
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(find.byType(EditableText));
      expect(input.style.color!.computeLuminance(), lessThan(0.2));
      final theme = Theme.of(tester.element(find.byType(TextFormField)));
      expect(theme.dialogTheme.backgroundColor?.a, 1);
      expect(theme.colorScheme.onSurface.computeLuminance(), lessThan(0.2));
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pumpAndSettle();
      await screenshot(tester, key, 'meta-pin-dialog-390');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile fields and all button states have readable contrast', (
    tester,
  ) async {
    final key = await show(tester, 390, FakeMetaService());
    final button = find.widgetWithText(FilledButton, 'Reconnect with Meta');
    final theme = Theme.of(tester.element(button));
    double contrast(Color a, Color b) {
      final first = a.computeLuminance(), second = b.computeLuminance();
      return first > second
          ? (first + 0.05) / (second + 0.05)
          : (second + 0.05) / (first + 0.05);
    }

    for (final states in [
      <WidgetState>{},
      {WidgetState.disabled},
    ]) {
      final style = theme.filledButtonTheme.style!;
      expect(
        contrast(
          style.foregroundColor!.resolve(states)!,
          style.backgroundColor!.resolve(states)!,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
    await tester.tap(find.text('Business profile'));
    await tester.pumpAndSettle();
    await screenshot(tester, key, 'meta-profile-390');
    await reveal(tester, 'Edit business profile');
    await tester.tap(find.text('Edit business profile'));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<EditableText>(
      find.byType(EditableText),
    )) {
      expect(field.style.color!.computeLuminance(), lessThan(0.2));
    }
    await screenshot(tester, key, 'meta-profile-dialog-390');
    expect(tester.takeException(), isNull);
  });

  testWidgets('200 percent text keeps the header and setup actions visible', (
    tester,
  ) async {
    final key = await show(tester, 390, FakeMetaService(), scale: 2);
    final title = tester.getRect(find.text('WhatsApp Business'));
    final toolbar = tester.getRect(find.byType(AppBar));
    expect(title.top, greaterThanOrEqualTo(toolbar.top));
    expect(title.bottom, lessThanOrEqualTo(toolbar.bottom));
    await screenshot(tester, key, 'meta-large-text-390');
    await reveal(tester, 'Enable');
    expect(find.text('Enable').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
