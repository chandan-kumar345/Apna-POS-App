import 'dart:async';

import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:apna_pos/features/auth/get_started_screen.dart';
import 'package:apna_pos/features/auth/splash_screen.dart';
import 'package:apna_pos/features/auth/widgets/logo_writing_reveal.dart';
import 'package:apna_pos/features/auth/widgets/splash_brand_view.dart';
import 'package:apna_pos/features/dashboard/main_layout.dart';
import 'package:apna_pos/features/notifications/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> finishTransition(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
  }

  testWidgets(
    'native startup handwriting continues without replaying letters',
    (tester) async {
      final ready = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initialize: () => ready.future,
            targetScreenOverride: const Scaffold(body: Text('Saved POS')),
          ),
        ),
      );
      await tester.pump();
      const codec = StandardMethodCodec();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'com.apnapos.app/startup_brand',
        codec.encodeMethodCall(const MethodCall('continueWriting', 1800)),
        (_) {},
      );
      await tester.pump();
      double progress() => tester
          .widget<LogoWritingReveal>(find.byType(LogoWritingReveal))
          .animation
          .value;
      expect(progress(), greaterThanOrEqualTo(0.5));
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'com.apnapos.app/startup_brand',
        codec.encodeMethodCall(const MethodCall('continueWriting', 400)),
        (_) {},
      );
      expect(progress(), greaterThanOrEqualTo(0.5));
      ready.complete();
      await tester.pump();
      await tester.pump(SplashScreen.writingDuration);
      await tester.pump();
      await finishTransition(tester);
      expect(find.text('Saved POS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      await tester.pump(const Duration(milliseconds: 1800));
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

      await tester.pump(
        SplashScreen.writingDuration -
            const Duration(milliseconds: 1800) +
            const Duration(milliseconds: 50),
      );
      await tester.pump();
      await finishTransition(tester);
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

    await tester.pump(
      SplashScreen.writingDuration + const Duration(milliseconds: 600),
    );
    await tester.pump();
    await finishTransition(tester);
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
      await tester.pump(
        SplashScreen.writingDuration + const Duration(milliseconds: 600),
      );
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
      await finishTransition(tester);
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
    await tester.pump(
      SplashScreen.writingDuration + const Duration(milliseconds: 100),
    );
    await tester.pump();
    await finishTransition(tester);
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
    await tester.pump(
      SplashScreen.writingDuration + const Duration(milliseconds: 600),
    );
    expect(find.text('Late destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final restored in [false, true]) {
    testWidgets(
      'completed splash restores the destination for saved session: $restored',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = DatabaseService();
        db.currentUser = restored
            ? UserModel(
                id: 'saved-owner',
                name: 'Owner',
                email: 'owner@example.test',
                role: 'Owner',
                pin: '',
                restaurantId: 'saved-business',
                onboardingCompleted: true,
              )
            : null;
        addTearDown(() => db.currentUser = null);
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
        await tester.pump();
        await tester.pump(
          SplashScreen.writingDuration - const Duration(milliseconds: 400),
        );
        expect(find.byType(GetStartedScreen), findsNothing);
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        // The completed artwork remains painted underneath the incoming fade;
        // there must be no separate fade-to-white phase before navigation.
        expect(
          find.byType(SplashBrandView, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SplashScreen, skipOffstage: false),
            matching: find.byType(AnimatedOpacity, skipOffstage: false),
            skipOffstage: false,
          ),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        expect(
          find.byType(GetStartedScreen),
          restored ? findsNothing : findsOneWidget,
        );
        expect(
          find.byType(MainLayout),
          restored ? findsOneWidget : findsNothing,
        );
        expect(db.currentUser != null, restored);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        if (restored) {
          // The actual POS destination starts app-wide monitors. Stop them after
          // verifying navigation so they do not leak into this widget test.
          SocketService().disconnect();
          NetworkService().dispose();
          NotificationService().dispose();
          await tester.pump(const Duration(seconds: 2));
        }
      },
    );
  }

  testWidgets('Get Started displays the new logo on narrow and wide screens', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: GetStartedScreen()));
      await tester.pump();
      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.image, const AssetImage(LogoWritingReveal.assetPath));
      expect(logo.semanticLabel, 'Apna POS');
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
