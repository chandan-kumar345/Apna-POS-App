import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/pos/pos_register_screen.dart';

void main() {
  group('Save Product Type Popup Redesign & Selection Tests', () {
    testWidgets('Save Product Type popup renders neumorphic design matching specification', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));

      ManualItemPersistenceMode? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  ManualItemPersistenceMode selectedMode = ManualItemPersistenceMode.permanent;

                  selectedResult = await showDialog<ManualItemPersistenceMode>(
                    context: ctx,
                    barrierDismissible: true,
                    builder: (confirmCtx) {
                      return StatefulBuilder(
                        builder: (confirmCtx, setModalState) {
                          final bool isTemporary = selectedMode == ManualItemPersistenceMode.temporary;
                          final bool isPermanent = selectedMode == ManualItemPersistenceMode.permanent;

                          return Dialog(
                            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F6FB),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x24000000),
                                      offset: Offset(0, 10),
                                      blurRadius: 28,
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Pill
                                      Center(
                                        child: Container(
                                          width: 44,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD3DCE6),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Header Row
                                      Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4F6FB),
                                              borderRadius: BorderRadius.circular(13),
                                            ),
                                            child: const Icon(
                                              Icons.local_offer_outlined,
                                              color: Color(0xFF0F172A),
                                              size: 19,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Save Product Type',
                                              style: TextStyle(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            key: const Key('close_dialog_button'),
                                            onTap: () => Navigator.pop(confirmCtx, null),
                                            child: const Icon(Icons.close_rounded, size: 17),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      // Item Summary Box
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Roti',
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text('₹12  •  5% GST'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // Option 1: Temporary Card
                                      InkWell(
                                        key: const Key('option_temporary_card'),
                                        onTap: () {
                                          setModalState(() {
                                            selectedMode = ManualItemPersistenceMode.temporary;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.shopping_cart_outlined),
                                              const SizedBox(width: 12),
                                              const Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(child: Text('Temporary')),
                                                    SizedBox(width: 8),
                                                    Text('Cart Only'),
                                                  ],
                                                ),
                                              ),
                                              if (isTemporary) const Icon(Icons.radio_button_checked, key: Key('temp_selected')),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // Option 2: Permanent Card
                                      InkWell(
                                        key: const Key('option_permanent_card'),
                                        onTap: () {
                                          setModalState(() {
                                            selectedMode = ManualItemPersistenceMode.permanent;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.bookmark_rounded),
                                              const SizedBox(width: 12),
                                              const Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(child: Text('Permanent')),
                                                    SizedBox(width: 8),
                                                    Text('Save to Menu'),
                                                  ],
                                                ),
                                              ),
                                              if (isPermanent) const Icon(Icons.radio_button_checked, key: Key('perm_selected')),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Buttons Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              key: const Key('cancel_button'),
                                              onTap: () => Navigator.pop(confirmCtx, null),
                                              child: const Center(child: Text('Cancel')),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: InkWell(
                                              key: const Key('save_button'),
                                              onTap: () => Navigator.pop(confirmCtx, selectedMode),
                                              child: const Center(child: Text('Save')),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      // Open Modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Check header, item summary, and badges
      expect(find.text('Save Product Type'), findsOneWidget);
      expect(find.text('Roti'), findsOneWidget);
      expect(find.text('₹12  •  5% GST'), findsOneWidget);
      expect(find.text('Temporary'), findsOneWidget);
      expect(find.text('Cart Only'), findsOneWidget);
      expect(find.text('Permanent'), findsOneWidget);
      expect(find.text('Save to Menu'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Initially Permanent is selected
      expect(find.byKey(const Key('perm_selected')), findsOneWidget);
      expect(find.byKey(const Key('temp_selected')), findsNothing);

      // Tap Temporary card
      await tester.tap(find.byKey(const Key('option_temporary_card')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('temp_selected')), findsOneWidget);
      expect(find.byKey(const Key('perm_selected')), findsNothing);

      // Tap Save
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(selectedResult, ManualItemPersistenceMode.temporary);
    });
  });
}
