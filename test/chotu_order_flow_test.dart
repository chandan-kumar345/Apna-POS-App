import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/chotu_service.dart';
import 'package:apna_pos/core/services/speech_recognition_service.dart';
import 'package:apna_pos/features/pos/widgets/chotu_voice_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chotu AI Voice Assistant - Order Flow Automation (Phases 2 & 3)', () {
    late ChotuService chotuService;
    late SpeechRecognitionService speechService;

    setUp(() {
      chotuService = ChotuService();
      speechService = SpeechRecognitionService();
      chotuService.clearHistory();
      speechService.reset();
    });

    test('ChotuParsedCommand serialization and deserialization', () {
      final jsonMap = {
        'intent': 'ADD_ITEM',
        'table_number': '12',
        'table_context_missing': false,
        'items': [
          {
            'product_id': 'prod_123',
            'product_name': 'Butter Naan',
            'price': 40.0,
            'quantity': 2,
            'foodType': 'veg',
            'modifiers': ['crispy'],
            'matched': true,
            'confidence': 0.98,
          },
          {
            'product_id': 'prod_456',
            'product_name': 'Paneer Tikka',
            'price': 240.0,
            'quantity': 1,
            'foodType': 'veg',
            'modifiers': ['spicy'],
            'matched': true,
            'confidence': 0.95,
          }
        ],
        'ambiguity': false,
        'question': null,
        'confidence': 0.95,
        'chotu_response': 'Table 12 mein Butter Naan 2 aur Paneer Tikka 1 add kar diya.',
      };

      final parsed = ChotuParsedCommand.fromMap(jsonMap, sessionId: 'sess_1', logId: 'log_1');
      expect(parsed.intent, 'ADD_ITEM');
      expect(parsed.tableNumber, '12');
      expect(parsed.tableContextMissing, false);
      expect(parsed.items.length, 2);
      expect(parsed.items[0].productName, 'Butter Naan');
      expect(parsed.items[0].quantity, 2);
      expect(parsed.items[0].modifiers, contains('crispy'));
      expect(parsed.items[1].productName, 'Paneer Tikka');
      expect(parsed.items[1].quantity, 1);
      expect(parsed.ambiguity, false);
      expect(parsed.sessionId, 'sess_1');

      final toMap = parsed.toMap();
      expect(toMap['intent'], 'ADD_ITEM');
      expect(toMap['table_number'], '12');
      expect((toMap['items'] as List).length, 2);
    });

    test('ChotuParsedCommand deserializes single item in UPDATE_QUANTITY', () {
      final jsonMap = {
        'intent': 'UPDATE_QUANTITY',
        'table_number': '5',
        'item': {
          'product_id': 'prod_123',
          'product_name': 'Butter Naan',
          'quantity': 4,
          'price': 40.0,
        },
        'ambiguity': false,
        'confidence': 0.95,
        'chotu_response': 'Table 5 mein Butter Naan ki quantity 4 set kar di.',
      };

      final parsed = ChotuParsedCommand.fromMap(jsonMap);
      expect(parsed.intent, 'UPDATE_QUANTITY');
      expect(parsed.tableNumber, '5');
      expect(parsed.items.length, 1);
      expect(parsed.items[0].productName, 'Butter Naan');
      expect(parsed.items[0].quantity, 4);
    });

    test('ChotuParsedCommand handles ambiguity and clarification question', () {
      final jsonMap = {
        'intent': 'ADD_ITEM',
        'table_number': '5',
        'items': [],
        'ambiguity': true,
        'question': 'Coca Cola 300ml ya Coca Cola 750ml? Kaunsa add karna hai?',
        'confidence': 0.70,
        'chotu_response': 'Coca Cola 300ml ya Coca Cola 750ml? Kaunsa add karna hai?',
      };

      final parsed = ChotuParsedCommand.fromMap(jsonMap);
      expect(parsed.ambiguity, true);
      expect(parsed.question, contains('Kaunsa add karna hai?'));
    });

    test('ChotuService client fallback parses multi-item Hinglish command when offline', () async {
      final parsed = await chotuService.parseCommand(
        speechText: 'Table 7 pe 2 butter naan aur 1 dal makhani laga do',
        tableNumber: '7',
      );

      expect(parsed.intent, 'ADD_ITEM');
      expect(parsed.tableNumber, '7');
      expect(parsed.items.length, 2);
      expect(parsed.items[0].quantity, 2);
      expect(parsed.items[0].productName, contains('butter naan'));
      expect(parsed.items[1].quantity, 1);
      expect(parsed.items[1].productName, contains('dal makhani'));
    });

    testWidgets('ChotuVoiceSheet displays big robot character and Start button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChotuVoiceSheet(tableNumber: '5'),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);

      // Tap Start to begin listening
      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('Listening... Bolie'), findsOneWidget);
    });

    test('ChotuService handles permanent and temporary missing product addition', () async {
      final service = ChotuService();

      // Test Permanent addition
      await service.addMissingProductPermanently(
        productName: 'Paneer Lababdar',
        quantity: 2,
        tableNumber: '5',
        price: 260.0,
      );

      final db = DatabaseService();
      final hasMenuItem = db.menuItems.any((m) => m.name == 'Paneer Lababdar');
      expect(hasMenuItem, true);

      final cart5 = db.getLiveTableCart('T-5');
      expect(cart5.any((c) => c.item.name == 'Paneer Lababdar' && c.quantity == 2), true);

      // Test Temporary addition
      await service.addMissingProductTemporarily(
        productName: 'Special Seasonal Shake',
        quantity: 1,
        tableNumber: '5',
        price: 120.0,
      );

      // Should be in table cart, but NOT in permanent menu
      final hasTempInMenu = db.menuItems.any((m) => m.name == 'Special Seasonal Shake');
      expect(hasTempInMenu, false);

      final cart5Updated = db.getLiveTableCart('T-5');
      expect(cart5Updated.any((c) => c.item.name == 'Special Seasonal Shake' && c.quantity == 1), true);
    });
  });
}
