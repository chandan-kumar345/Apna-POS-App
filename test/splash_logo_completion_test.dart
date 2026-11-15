import 'package:apna_pos/features/auth/splash_screen.dart';
import 'package:apna_pos/features/auth/widgets/logo_writing_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('late Android handoff cannot skip the full-logo reveal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          targetScreenOverride: Scaffold(body: Text('Next screen')),
        ),
      ),
    );
    await tester.pump();
    const codec = StandardMethodCodec();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'com.apnapos.app/startup_brand',
      codec.encodeMethodCall(const MethodCall('continueWriting', 12000)),
      (_) {},
    );
    await tester.pump();
    final writing = tester.widget<LogoWritingReveal>(
      find.byType(LogoWritingReveal),
    );
    expect(
      writing.animation.value,
      lessThan(0.9),
      reason:
          'The original glossy logo must still resolve after a slow Android launch.',
    );
    expect(
      writing.animation.value,
      greaterThanOrEqualTo(0.83),
      reason:
          'Do not replay an already completed native receipt from invisible.',
    );
    expect(find.text('Next screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(
      tester
          .widget<LogoWritingReveal>(find.byType(LogoWritingReveal))
          .animation
          .value,
      1,
    );
    expect(find.text('Next screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Next screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Next screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('completed logo remains visible before navigating', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          targetScreenOverride: Scaffold(body: Text('Next screen')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(SplashScreen.writingDuration);
    await tester.pump();
    expect(
      tester
          .widget<LogoWritingReveal>(find.byType(LogoWritingReveal))
          .animation
          .value,
      1,
    );
    expect(find.text('Next screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Next screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Next screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
