import 'dart:async';

import 'package:apna_pos/features/auth/splash_screen.dart';
import 'package:apna_pos/features/auth/widgets/logo_writing_reveal.dart';
import 'package:apna_pos/features/auth/widgets/splash_brand_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'splash finishes writing before opening the resolved destination',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            targetScreenOverride: Scaffold(body: Text('Destination')),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2300));
      expect(find.byType(SplashBrandView), findsOneWidget);
      expect(SplashScreen.isSplashActive, isTrue);
      expect(find.text('Destination'), findsNothing);
      expect(
        tester
            .widget<LogoWritingReveal>(find.byType(LogoWritingReveal))
            .animation
            .value,
        lessThan(1),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Destination'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(SplashScreen.isSplashActive, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallback still exits when animation ticking is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: SplashScreen(
            targetScreenOverride: Scaffold(body: Text('Fallback destination')),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Fallback destination'), findsOneWidget);
    expect(SplashScreen.isSplashActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(740, 320),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'splash fits ${size.width} x ${size.height} with enlarged text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(1.6),
              ),
              child: const SplashBrandView(
                animation: AlwaysStoppedAnimation(1),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.bySemanticsLabel('Apna POS'), findsOneWidget);
        final logo = tester.widget<LogoWritingReveal>(
          find.byType(LogoWritingReveal),
        );
        expect(logo.size, greaterThan(0));
        expect(find.text('SMART RESTAURANT POS'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'reduced motion keeps the logo visible without entrance movement',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SplashBrandView(animation: AlwaysStoppedAnimation(0)),
          ),
        ),
      );

      expect(
        tester
            .widget<LogoWritingReveal>(find.byType(LogoWritingReveal))
            .animation
            .value,
        1,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'branding paints before slow initialization and waits for the saved session',
    (tester) async {
      final ready = Completer<void>();
      SchedulerPhase? phaseAtInitialization;
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initialize: () {
              phaseAtInitialization = SchedulerBinding.instance.schedulerPhase;
              return ready.future;
            },
            targetScreenOverride: const Scaffold(body: Text('Restored POS')),
          ),
        ),
      );
      expect(phaseAtInitialization, SchedulerPhase.postFrameCallbacks);
      expect(find.bySemanticsLabel('Apna POS'), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3200));
      expect(find.text('Restored POS'), findsNothing);
      expect(find.text('Preparing your workspace...'), findsOneWidget);
      expect(
        tester
            .widget<LogoWritingReveal>(find.byType(LogoWritingReveal))
            .animation
            .value,
        1,
      );

      ready.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Restored POS'), findsOneWidget);
      expect(SplashScreen.isSplashActive, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('startup failure recovers without a blank or stuck splash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          initialize: () async =>
              throw StateError('Local initialization failed'),
          targetScreenOverride: const Scaffold(
            body: Text('Recovery destination'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Recovery destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during initialization does not navigate later', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          initialize: () => ready.future,
          targetScreenOverride: const Scaffold(body: Text('Late destination')),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    ready.complete();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Late destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
