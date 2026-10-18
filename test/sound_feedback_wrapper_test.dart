import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/core/widgets/sound_feedback_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int clickSoundCount = 0;

  setUp(() {
    SoundService.soundEnabled = true;
    clickSoundCount = 0;
    SoundService.onButtonClickForTest = () {
      clickSoundCount++;
    };
  });

  tearDown(() {
    SoundService.soundEnabled = false;
    SoundService.onButtonClickForTest = null;
  });

  testWidgets('SoundFeedbackWrapper plays click sound on buttons ONLY and ignores non-buttons', (tester) async {
    bool elevatedPressed = false;
    bool iconPressed = false;
    bool inkWellPressed = false;
    bool gesturePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SoundFeedbackWrapper(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ElevatedButton(
                  key: const Key('elevated_btn'),
                  onPressed: () {
                    elevatedPressed = true;
                  },
                  child: const Text('Elevated'),
                ),
                IconButton(
                  key: const Key('icon_btn'),
                  onPressed: () {
                    iconPressed = true;
                  },
                  icon: const Icon(Icons.add),
                ),
                InkWell(
                  key: const Key('ink_well'),
                  onTap: () {
                    inkWellPressed = true;
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('InkWell Button'),
                  ),
                ),
                GestureDetector(
                  key: const Key('gesture_btn'),
                  onTap: () {
                    gesturePressed = true;
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.red,
                    child: const Text('Gesture'),
                  ),
                ),
                const ElevatedButton(
                  key: Key('disabled_btn'),
                  onPressed: null,
                  child: Text('Disabled'),
                ),
                const TextField(
                  key: Key('text_field'),
                ),
                Container(
                  key: const Key('plain_box'),
                  width: 100,
                  height: 100,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(clickSoundCount, 0);

    // 1. Tap elevated button -> plays click sound and triggers onPressed
    await tester.tap(find.byKey(const Key('elevated_btn')));
    await tester.pumpAndSettle();
    expect(elevatedPressed, isTrue);
    expect(clickSoundCount, 1);

    SoundService.resetDebounceForTest();

    // 2. Tap icon button -> plays click sound and triggers onPressed
    await tester.tap(find.byKey(const Key('icon_btn')));
    await tester.pumpAndSettle();
    expect(iconPressed, isTrue);
    expect(clickSoundCount, 2);

    SoundService.resetDebounceForTest();

    // 3. Tap ink well button -> plays click sound
    await tester.tap(find.byKey(const Key('ink_well')));
    await tester.pumpAndSettle();
    expect(inkWellPressed, isTrue);
    expect(clickSoundCount, 3);

    SoundService.resetDebounceForTest();

    // 4. Tap gesture detector button -> plays click sound
    await tester.tap(find.byKey(const Key('gesture_btn')));
    await tester.pumpAndSettle();
    expect(gesturePressed, isTrue);
    expect(clickSoundCount, 4);

    SoundService.resetDebounceForTest();

    // 5. Tap plain non-button container -> SILENCE (clickSoundCount remains 4)
    await tester.tap(find.byKey(const Key('plain_box')));
    await tester.pumpAndSettle();
    expect(clickSoundCount, 4);

    // 6. Tap text field -> SILENCE (clickSoundCount remains 4)
    await tester.tap(find.byKey(const Key('text_field')));
    await tester.pumpAndSettle();
    expect(clickSoundCount, 4);

    // 7. Tap disabled button -> SILENCE (clickSoundCount remains 4)
    await tester.tap(find.byKey(const Key('disabled_btn')));
    await tester.pumpAndSettle();
    expect(clickSoundCount, 4);

    // 8. Drag / Scroll single child scroll view -> SILENCE (clickSoundCount remains 4)
    await tester.drag(find.byKey(const Key('plain_box')), const Offset(0, -50));
    await tester.pumpAndSettle();
    expect(clickSoundCount, 4);
  });

  testWidgets('SoundFeedbackWrapper remains completely silent when soundEnabled is false', (tester) async {
    SoundService.soundEnabled = false;

    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SoundFeedbackWrapper(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: ElevatedButton(
            key: const Key('test_btn'),
            onPressed: () {
              pressed = true;
            },
            child: const Text('Test'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('test_btn')));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
    expect(clickSoundCount, 0);
  });

  testWidgets('SoundFeedbackWrapper plays click sound on buttons inside dialogs and bottom sheets', (tester) async {
    bool dialogButtonPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SoundFeedbackWrapper(child: child ?? const SizedBox.shrink()),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              key: const Key('open_dialog_btn'),
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Dialog Title'),
                    actions: [
                      TextButton(
                        key: const Key('dialog_action_btn'),
                        onPressed: () {
                          dialogButtonPressed = true;
                          Navigator.pop(dialogCtx);
                        },
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();
    expect(clickSoundCount, 1);

    SoundService.resetDebounceForTest();

    // Tap dialog action button
    expect(find.byKey(const Key('dialog_action_btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dialog_action_btn')));
    await tester.pumpAndSettle();

    expect(dialogButtonPressed, isTrue);
    expect(clickSoundCount, 2);
  });

  test('SoundService toggling works correctly and updates soundEnabled', () async {
    SoundService.soundEnabled = false;
    expect(SoundService.soundEnabled, isFalse);

    await SoundService.setSoundEnabled(true);
    expect(SoundService.soundEnabled, isTrue);

    await SoundService.setSoundEnabled(false);
    expect(SoundService.soundEnabled, isFalse);
  });
}
