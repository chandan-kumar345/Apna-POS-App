import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/features/settings/business_settings_hub_screen.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    await db.init();
    final testRestaurant = RestaurantModel(
      id: 'test_rest_1',
      name: 'Apna Test Diner',
      companyName: 'Apna POS Tech Ltd',
      tagline: 'Best in Town',
      phone: '+91 9999999999',
      address: '123 Market Street',
      cuisineType: 'North Indian',
      taxRate: 5.0,
      upiId: 'test@upi',
      posViewMode: 'with_image',
    );
    await db.updateRestaurantProfile(testRestaurant);
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      home: Scaffold(
        body: BusinessSettingsHubScreen(),
      ),
    );
  }

  testWidgets('BusinessSettingsHubScreen renders hero card and categories with all cards on desktop', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify outlet name, company name & hero card Edit button
    expect(find.text('Apna Test Diner'), findsOneWidget);
    expect(find.text('Apna POS Tech Ltd'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    // Verify category headers for normal user
    expect(find.text('Store & Order Configuration'), findsOneWidget);
    expect(find.text('Financials & Payments'), findsOneWidget);
    expect(find.text('Hardware & Logistics'), findsOneWidget);
    expect(find.text('Marketing & Communication'), findsOneWidget);
    expect(find.text('Super Admin & Database'), findsNothing);

    // Verify key cards
    expect(find.text('Order Setting'), findsOneWidget);
    expect(find.text('POS View'), findsOneWidget);
    expect(find.text('Outlet Info'), findsOneWidget);
    expect(find.text('Print Logs'), findsOneWidget);
    expect(find.text('Security PIN'), findsOneWidget);
    expect(find.text('Chotu AI Voice'), findsOneWidget);
    expect(find.text('Payment Setting'), findsOneWidget);
    expect(find.text('Tax Settings'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Printer Setting'), findsOneWidget);
    expect(find.text('Sound Setting'), findsOneWidget);
    expect(find.text('Meta Integration'), findsOneWidget);
    expect(find.text('WhatsApp Integration'), findsOneWidget);
    expect(find.text('WhatsApp Messages'), findsOneWidget);
    expect(find.text('AI Chat Agent'), findsOneWidget);
    expect(find.text('Meta Chats'), findsOneWidget);
    expect(find.text('Order Purge'), findsNothing);
  });

  testWidgets('Super Admin user sees Super Admin & Database category and Order Purge card', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final db = DatabaseService();
    db.currentUser = UserModel(
      id: 'super_1',
      name: 'Super Admin',
      email: 'admin@pos.com',
      role: 'SuperAdmin',
      pin: '1234',
      restaurantId: 'rest_001',
    );

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Super Admin & Database'), findsOneWidget);
    expect(find.text('Order Purge'), findsOneWidget);
  });

  testWidgets('Tapping Edit button in Hero Card opens Edit Business Profile modal and saves updates', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final editBtn = find.text('Edit');
    expect(editBtn, findsOneWidget);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    // Verify modal contents
    expect(find.text('Edit Business Profile'), findsOneWidget);
    expect(find.text('PRESENT PROFILE DATA'), findsNothing);
    expect(find.text('Change Logo'), findsOneWidget);
    expect(find.text('Business Profile Name *'), findsOneWidget);
    expect(find.text('Contact / Owner Name'), findsOneWidget);
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Phone Number *'), findsOneWidget);
    expect(find.text('Save Profile'), findsOneWidget);

    // Enter updated details
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(4));

    await tester.enterText(textFields.at(0), 'Updated Gourmet Kitchen');
    await tester.enterText(textFields.at(1), 'Updated Master Chef');
    await tester.enterText(textFields.at(2), 'Updated Holdings Pvt Ltd');
    await tester.enterText(textFields.at(3), '+91 8888888888');

    // Save profile
    final saveBtn = find.text('Save Profile');
    expect(saveBtn, findsOneWidget);
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verify modal closed and hero updated
    expect(find.text('Edit Business Profile'), findsNothing);
    expect(find.text('Updated Gourmet Kitchen'), findsOneWidget);
    expect(find.text('Updated Holdings Pvt Ltd'), findsOneWidget);

    // Verify DatabaseService has updated data
    final db = DatabaseService();
    expect(db.restaurant?.name, 'Updated Gourmet Kitchen');
    expect(db.restaurant?.companyName, 'Updated Holdings Pvt Ltd');
    expect(db.restaurant?.phone, '+91 8888888888');
    expect(db.currentUser?.name, 'Updated Master Chef');
  });

  testWidgets('BusinessSettingsHubScreen wraps smoothly on compact mobile view without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Apna Test Diner'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('Order Setting'), findsOneWidget);
  });

  testWidgets('Tapping POS View card opens Neumorphic POS View modal', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final posViewCard = find.text('POS View');
    expect(posViewCard, findsOneWidget);
    await tester.tap(posViewCard);
    await tester.pumpAndSettle();

    expect(find.text('POS View Setting'), findsOneWidget);
    expect(find.text('With Image'), findsWidgets);
    expect(find.text('Without Image'), findsOneWidget);
    expect(find.text('Save POS View'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('POS View Setting'), findsNothing);
  });

  testWidgets('Tapping Chotu AI Voice card opens Chotu voice modal', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final chotuCard = find.text('Chotu AI Voice');
    expect(chotuCard, findsOneWidget);
    await tester.tap(chotuCard);
    await tester.pumpAndSettle();

    expect(find.text('Chotu AI Voice Assistant'), findsOneWidget);
    expect(find.text('Enable Chotu AI'), findsOneWidget);
    expect(find.text('Disable Chotu AI'), findsOneWidget);
    expect(find.text('Save Setting'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Chotu AI Voice Assistant'), findsNothing);
  });

  testWidgets('Tapping Payment Setting opens UPI modal', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final paymentCard = find.text('Payment Setting');
    expect(paymentCard, findsOneWidget);
    await tester.tap(paymentCard);
    await tester.pumpAndSettle();

    expect(find.text('Save Payment Setting'), findsOneWidget);
    expect(find.text('Merchant UPI VPA ID *'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Save Payment Setting'), findsNothing);
  });

  testWidgets('Tapping Security PIN card opens PIN modal and closes cleanly', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final pinCard = find.text('Security PIN');
    expect(pinCard, findsOneWidget);
    await tester.tap(pinCard);
    await tester.pumpAndSettle();

    expect(find.text('Security / Manager PIN'), findsOneWidget);
    expect(find.text('Auto Generate'), findsOneWidget);
    expect(find.text('Save PIN'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Security / Manager PIN'), findsNothing);
  });

  testWidgets('Tapping Meta Integration card opens Meta modal, updates values, and saves', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final metaCard = find.text('Meta Integration');
    expect(metaCard, findsOneWidget);
    await tester.ensureVisible(metaCard);
    await tester.tap(metaCard);
    await tester.pumpAndSettle();

    expect(find.text('Meta System User Access Token'), findsOneWidget);
    expect(find.text('Enable Meta Integration'), findsOneWidget);
    expect(find.text('Facebook Pixel / Dataset ID'), findsOneWidget);
    expect(find.text('Instagram Handle'), findsOneWidget);
    expect(find.text('Test Meta Connection'), findsOneWidget);
    expect(find.text('Save Meta Settings'), findsOneWidget);

    final saveBtn = find.text('Save Meta Settings');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Facebook Pixel / Dataset ID'), findsNothing);
  });

  testWidgets('Tapping WhatsApp Integration card opens WhatsApp modal and saves', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final waCard = find.text('WhatsApp Integration');
    expect(waCard, findsOneWidget);
    await tester.ensureVisible(waCard);
    await tester.tap(waCard);
    await tester.pumpAndSettle();

    expect(find.text('Cloud API, Phone Number & Webhooks'), findsOneWidget);
    expect(find.text('Meta Cloud API'), findsOneWidget);
    expect(find.text('Twilio'), findsOneWidget);
    expect(find.text('QR Gateway'), findsOneWidget);
    expect(find.text('Sender Business Phone Number *'), findsOneWidget);
    expect(find.text('Save WhatsApp Gateway'), findsOneWidget);

    final saveBtn = find.text('Save WhatsApp Gateway');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Cloud API, Phone Number & Webhooks'), findsNothing);
  });

  testWidgets('Tapping WhatsApp Messages card opens template customizer modal and saves', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final msgCard = find.text('WhatsApp Messages');
    expect(msgCard, findsOneWidget);
    await tester.ensureVisible(msgCard);
    await tester.tap(msgCard);
    await tester.pumpAndSettle();

    expect(find.text('Automations, Instant Invoices & Custom Templates'), findsOneWidget);
    expect(find.text('Auto Send Bill on Settlement'), findsOneWidget);
    expect(find.text('KOT & Order Status Updates'), findsOneWidget);
    expect(find.text('Payment Reminders'), findsOneWidget);
    expect(find.text('Loyalty & Birthday Greetings'), findsOneWidget);
    expect(find.text('LIVE CUSTOMER PREVIEW'), findsOneWidget);
    expect(find.text('Save Message Settings'), findsOneWidget);

    final saveBtn = find.text('Save Message Settings');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Automations, Instant Invoices & Custom Templates'), findsNothing);
  });

  testWidgets('Tapping AI Chat Agent card opens AI agent modal and saves', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final aiCard = find.text('AI Chat Agent');
    expect(aiCard, findsOneWidget);
    await tester.ensureVisible(aiCard);
    await tester.tap(aiCard);
    await tester.pumpAndSettle();

    expect(find.text('Autonomous Hospitality & Order Assistant'), findsOneWidget);
    expect(find.text('AI Welcome Greeting Message'), findsOneWidget);
    expect(find.text('Smart Menu Recommendations'), findsOneWidget);
    expect(find.text('Direct Order & Cart Taking'), findsOneWidget);
    expect(find.text('AI Agent Simulator'), findsOneWidget);
    expect(find.text('Save AI Agent'), findsOneWidget);

    final saveBtn = find.text('Save AI Agent');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Autonomous Hospitality & Order Assistant'), findsNothing);
  });

  testWidgets('Tapping Meta Chats card opens Meta Chats modal and saves', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final metaChatsCard = find.text('Meta Chats');
    expect(metaChatsCard, findsOneWidget);
    await tester.ensureVisible(metaChatsCard);
    await tester.tap(metaChatsCard);
    await tester.pumpAndSettle();

    expect(find.text('Messenger & Instagram Direct Automated Inboxes'), findsOneWidget);
    expect(find.text('Enable Meta Chats Automation'), findsOneWidget);
    expect(find.text('Auto Welcome Greeting'), findsOneWidget);
    expect(find.text('Social Lead Capture'), findsOneWidget);
    expect(find.text('Staff / Human Handover Trigger Keywords'), findsOneWidget);
    expect(find.text('Save Meta Chats'), findsOneWidget);

    final saveBtn = find.text('Save Meta Chats');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Messenger & Instagram Direct Automated Inboxes'), findsNothing);
  });

  testWidgets('Tapping Wallet card opens Wallet settings modal and saves', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final walletCard = find.text('Wallet');
    expect(walletCard, findsOneWidget);
    await tester.ensureVisible(walletCard);
    await tester.tap(walletCard);
    await tester.pumpAndSettle();

    expect(find.text('Customer & Outlet Wallet'), findsOneWidget);
    expect(find.text('Prepaid Balances, Cashbacks & Payouts'), findsOneWidget);
    expect(find.text('Enable Wallet System'), findsOneWidget);
    expect(find.text('Recharge Cashback (%)'), findsOneWidget);
    expect(find.text('Min Recharge (₹)'), findsOneWidget);
    expect(find.text('Allow Trusted Negative Credit (Khata Tab)'), findsOneWidget);
    expect(find.text('Merchant Payout UPI VPA (Settlements)'), findsOneWidget);
    expect(find.text('Save Wallet Settings'), findsOneWidget);

    final saveBtn = find.text('Save Wallet Settings');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Customer & Outlet Wallet'), findsNothing);
  });
}
