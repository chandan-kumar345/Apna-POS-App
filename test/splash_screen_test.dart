import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/features/auth/splash_screen.dart';
import 'package:apna_pos/core/database/database_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    await db.init();
  });

  testWidgets('SplashScreen renders animated logo, double-wrapped card and slogan without overflow', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Initial frame
    await tester.pump(const Duration(milliseconds: 100));

    // Verify brand slogan pill and tagline are rendered
    expect(find.text('SMART RESTAURANT POS'), findsOneWidget);
    expect(find.text('Fast • Simple • Reliable'), findsOneWidget);

    // Pump through zoom animation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('SplashScreen wraps properly on compact screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(340, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SMART RESTAURANT POS'), findsOneWidget);
    expect(find.text('Fast • Simple • Reliable'), findsOneWidget);
  });
}
