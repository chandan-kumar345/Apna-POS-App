import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Manual Products History & Autocomplete', () {
    test('saveManualProductToHistory and searchManualProductsHistory with user isolation', () async {
      final db = DatabaseService();
      await db.init();

      db.currentUser = UserModel(
        id: 'user_alice_123',
        name: 'Alice',
        email: 'alice@pos.com',
        phone: '9876543210',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'rest_alice',
      );

      // Initially empty
      expect(db.searchManualProductsHistory(''), isEmpty);

      // Add "Water Bottle" and "Extra Roti"
      await db.saveManualProductToHistory(
        name: 'Water Bottle 1L',
        price: 20.0,
        foodType: 'Veg',
        gstPercent: 0.0,
      );
      await db.saveManualProductToHistory(
        name: 'Extra Butter Roti',
        price: 15.0,
        foodType: 'Veg',
        gstPercent: 5.0,
      );

      // Search matching "wat" -> finds "Water Bottle 1L"
      final watMatches = db.searchManualProductsHistory('wat');
      expect(watMatches.length, 1);
      expect(watMatches.first.name, 'Water Bottle 1L');
      expect(watMatches.first.price, 20.0);

      // Search matching "roti" -> finds "Extra Butter Roti"
      final rotiMatches = db.searchManualProductsHistory('roti');
      expect(rotiMatches.length, 1);
      expect(rotiMatches.first.name, 'Extra Butter Roti');
      expect(rotiMatches.first.price, 15.0);

      // Update price of "Water Bottle 1L" to 25.0
      await db.saveManualProductToHistory(
        name: 'Water Bottle 1L',
        price: 25.0,
        foodType: 'Veg',
        gstPercent: 0.0,
      );

      // Search again -> should have 1 item with updated price 25.0
      final updatedMatches = db.searchManualProductsHistory('water');
      expect(updatedMatches.length, 1);
      expect(updatedMatches.first.price, 25.0);

      // Switch user to Bob -> Bob should have isolated empty history
      db.currentUser = UserModel(
        id: 'user_bob_456',
        name: 'Bob',
        email: 'bob@pos.com',
        phone: '9876543211',
        role: 'Owner',
        pin: '1234',
        restaurantId: 'rest_bob',
      );
      await db.loadUserDataForActiveUser('user_bob_456');
      expect(db.searchManualProductsHistory('water'), isEmpty);
    });

    testWidgets('Manual product history suggestion chips populate fields and allow price editing', (WidgetTester tester) async {
      final db = DatabaseService();
      db.currentUser = UserModel(
        id: 'test_cashier_1',
        name: 'Cashier',
        email: 'cashier@pos.com',
        phone: '9999999999',
        role: 'Cashier',
        pin: '1234',
        restaurantId: 'rest_test',
      );
      db.restaurant = RestaurantModel(
        id: 'rest_test',
        name: 'Test Restaurant',
        tagline: 'Fresh & Fast',
        phone: '9999999999',
        address: 'MG Road',
        cuisineType: 'Indian',
        currencySymbol: '₹',
      );

      // Pre-seed manual history with "Water" and "Cold Coffee"
      await db.saveManualProductToHistory(
        name: 'Water',
        price: 20.0,
        foodType: 'Veg',
        gstPercent: 0.0,
      );
      await db.saveManualProductToHistory(
        name: 'Cold Coffee',
        price: 80.0,
        foodType: 'Veg',
        gstPercent: 5.0,
      );

      final nameController = TextEditingController();
      final priceController = TextEditingController();
      List<ManualProductHistoryItem> matchingSuggestions = db.searchManualProductsHistory('');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            key: const Key('manual_item_name_field'),
                            controller: nameController,
                            onChanged: (val) {
                              setDialogState(() {
                                matchingSuggestions = db.searchManualProductsHistory(val);
                              });
                            },
                          ),
                          // Suggestions
                          if (matchingSuggestions.isNotEmpty)
                            SizedBox(
                              height: 30,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: matchingSuggestions.length,
                                itemBuilder: (ctx, idx) {
                                  final sug = matchingSuggestions[idx];
                                  return ActionChip(
                                    key: Key('sug_${sug.name}'),
                                    label: Text('${sug.name} (₹${sug.price.toInt()})'),
                                    onPressed: () {
                                      setDialogState(() {
                                        nameController.text = sug.name;
                                        priceController.text = sug.price.toInt().toString();
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          TextField(
                            key: const Key('manual_price_field'),
                            controller: priceController,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify suggestion chips are displayed
      expect(find.byKey(const Key('sug_Water')), findsOneWidget);
      expect(find.byKey(const Key('sug_Cold Coffee')), findsOneWidget);

      // Tap on "Water (₹20)" suggestion chip
      await tester.tap(find.byKey(const Key('sug_Water')));
      await tester.pump();

      // Verify name and price are populated
      expect(nameController.text, 'Water');
      expect(priceController.text, '20');

      // Edit price to 25
      await tester.enterText(find.byKey(const Key('manual_price_field')), '25');
      await tester.pump();
      expect(priceController.text, '25');
    });
  });
}
