import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/services/speech_recognition_service.dart';
import 'package:apna_pos/core/services/chotu_service.dart';
import 'package:apna_pos/features/pos/widgets/chotu_mic_button.dart';
import 'package:apna_pos/features/pos/widgets/chotu_voice_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chotu AI Voice Assistant - Phase 1 Voice Foundation', () {
    late SpeechRecognitionService speechService;
    late ChotuService chotuService;

    setUp(() {
      speechService = SpeechRecognitionService();
      chotuService = ChotuService();
      speechService.reset();
      chotuService.clearHistory();
    });

    test('SpeechRecognitionService state transitions and simulation', () async {
      expect(speechService.status, SpeechStatus.idle);
      expect(speechService.isListening, false);

      await speechService.startListening();
      expect(speechService.status, SpeechStatus.listening);
      expect(speechService.isListening, true);

      speechService.updateTranscription('Table 5 pe do butter naan');
      expect(speechService.liveTranscription, 'Table 5 pe do butter naan');

      speechService.stopListening();
      expect(speechService.status, SpeechStatus.done);
      expect(speechService.isListening, false);
    });

    test('ChotuService local normalization handles Hindi numerals while preserving verbs', () async {
      chotuService.setTableContext('5');
      expect(chotuService.currentTableContext, '5');

      // Transcribe Hinglish phrase with numeral 'do' and verbal 'laga do'
      final result = await chotuService.transcribe(
        speechText: 'Table 5 pe do butter naan aur ek paneer tikka laga do',
        tableNumber: '5',
      );

      expect(result.success, true);
      // Check that "do butter naan" -> "2 butter naan", "ek" -> "1", and "laga do" remains verbal "laga do"
      expect(result.transcription, contains('2 butter naan'));
      expect(result.transcription, contains('1 paneer tikka'));
      expect(result.transcription, contains('laga do'));

      // Check history
      expect(chotuService.history.length, 1);
      expect(chotuService.lastResult, isNotNull);
    });

    test('ChotuService handles Hindi number variations', () async {
      final result = await chotuService.transcribe(
        speechText: 'Table 8 pe teen coke aur chaar naan kar do',
      );

      expect(result.success, true);
      expect(result.transcription, contains('3 coke'));
      expect(result.transcription, contains('4 naan'));
      expect(result.transcription, contains('kar do'));
    });

    testWidgets('ChotuMicButton renders robot icon image and respects permission', (WidgetTester tester) async {
      final db = DatabaseService();
      db.restaurant = RestaurantModel(
        id: 'test_rest',
        name: 'Test Dhaba',
        tagline: 'Best food',
        phone: '1234567890',
        address: 'Delhi',
        cuisineType: 'Indian',
        enableChotuVoice: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChotuMicButton(tableNumber: '5', isCompact: true),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byTooltip('Chotu AI Voice Assistant'), findsOneWidget);

      // Verify that when permission is disabled, the button hides completely
      db.restaurant = db.restaurant!.copyWith(enableChotuVoice: false);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChotuMicButton(tableNumber: '5', isCompact: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Tapping ChotuMicButton opens growing robot overlay with BackdropFilter blur', (WidgetTester tester) async {
      final db = DatabaseService();
      db.restaurant = RestaurantModel(
        id: 'test_rest',
        name: 'Test Dhaba',
        tagline: 'Best food',
        phone: '1234567890',
        address: 'Delhi',
        cuisineType: 'Indian',
        enableChotuVoice: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChotuMicButton(tableNumber: '5'),
            ),
          ),
        ),
      );

      expect(find.byType(ChotuMicButton), findsOneWidget);

      // Tap on Chotu robot icon button
      await tester.tap(find.byType(ChotuMicButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify full-screen overlay opens with BackdropFilter blur and robot
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(find.byType(ChotuVoiceSheet), findsOneWidget);
      expect(find.byType(Image), findsWidgets);

      // Verify tapping blurred background dismisses overlay
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ChotuVoiceSheet), findsNothing);
    });

    testWidgets('Android view: search field has decreased width and ChotuMicButton is beside search box (outside suffixIcon)', (WidgetTester tester) async {
      final db = DatabaseService();
      db.restaurant = RestaurantModel(
        id: 'test_rest',
        name: 'Test Dhaba',
        tagline: 'Best food',
        phone: '1234567890',
        address: 'Delhi',
        cuisineType: 'Indian',
        enableChotuVoice: true,
      );

      // Render the Android search bar structure
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products by name or category...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                  ),
                  if (db.isChotuVoiceEnabled) ...[
                    const SizedBox(width: 10),
                    const ChotuMicButton(isCompact: false),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      // Verify TextField has no ChotuMicButton in suffixIcon
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.suffixIcon, isNull);

      // Verify ChotuMicButton is in the widget tree alongside TextField
      expect(find.byType(ChotuMicButton), findsOneWidget);

      // Verify Row contains both Expanded (TextField) and ChotuMicButton side by side
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.length, greaterThanOrEqualTo(2));
      expect(find.descendant(of: find.byType(Row), matching: find.byType(TextField)), findsOneWidget);
      expect(find.descendant(of: find.byType(Row), matching: find.byType(ChotuMicButton)), findsOneWidget);
    });
  });
}
