import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/features/settings/ai_chat_agent_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'apna_pos_wa_enabled': true,
      'apna_pos_wa_phone_id': '1284061438133660',
      'apna_pos_wa_phone_number': '+91 9709593705',
      'apna_pos_ai_agent_enabled': true,
      'apna_pos_ai_agent_order_taking': true,
      'apna_pos_ai_agent_persona': 'friendly',
    });
    final db = DatabaseService();
    await db.init();
    db.restaurant = RestaurantModel(
      id: 'rest_01',
      name: 'Shri Sai Cafe',
      tagline: 'Best Cafe',
      phone: '+91 9709593705',
      address: '123 Market Street',
      cuisineType: 'Cafe',
    );
  });

  tearDown(() {
    NetworkService().dispose();
  });

  testWidgets('AiChatAgentScreen renders wrapped layout, compact texts, and all feature cards', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AiChatAgentScreen(),
      ),
    );

    // Initial pump & settle
    await tester.pumpAndSettle();

    // 1. Header Verification
    expect(find.text('AI Chat Agent Settings'), findsOneWidget);
    expect(find.text('Shri Sai Cafe • WhatsApp POS Assistant'), findsOneWidget);

    // 2. Wrapped Container Verification
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(Center),
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(constrainedBox.constraints.maxWidth, 680);

    // 3. Meta API Connection Card
    expect(find.text('Meta Cloud API Connected'), findsOneWidget);
    expect(find.text('Activate Autonomous AI Auto-Reply'), findsOneWidget);

    // 4. Direct Order Taking Card
    expect(find.text('DIRECT ORDER TAKING IN CHAT'), findsOneWidget);
    expect(find.text('Auto-Create POS Order'), findsOneWidget);
    expect(find.text('Suggest Bestsellers'), findsOneWidget);

    // 5. Identity & Greeting
    expect(find.text('IDENTITY & GREETING'), findsOneWidget);
    expect(find.text('Assistant Display Name'), findsOneWidget);
    expect(find.text('Welcome Greeting Template'), findsOneWidget);

    // 6. Conversational Persona
    expect(find.text('CONVERSATIONAL PERSONA'), findsOneWidget);
    expect(find.text('Friendly'), findsOneWidget);
    expect(find.text('Hinglish'), findsOneWidget);
    expect(find.text('Chef Host'), findsOneWidget);

    // 7. Special House Rules
    expect(find.text('SPECIAL HOUSE RULES'), findsOneWidget);
    expect(find.text('Custom Instructions for AI'), findsOneWidget);

    // 8. AI Engine & Gemini Server Key Included
    expect(find.text('AI ENGINE & SPEED'), findsOneWidget);
    expect(find.text('Google Gemini 3.8 Flash Engine'), findsOneWidget);
    expect(find.text('Platform-wide server AI included • No merchant key required'), findsOneWidget);
    expect(find.text('Included ✅'), findsOneWidget);

    // 9. Live WhatsApp Simulator
    expect(find.text('LIVE WHATSAPP SIMULATOR'), findsOneWidget);
    expect(find.text('Live WhatsApp Chat Simulator'), findsOneWidget);

    // 10. Save & Sync Button
    expect(find.text('Save & Sync AI Chat Agent'), findsOneWidget);

    // Tap Save and verify
    await tester.tap(find.text('Save & Sync AI Chat Agent'));
    await tester.pumpAndSettle();
  });
}
