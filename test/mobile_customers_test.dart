import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/campaign/mobile/create_customer_group_screen.dart';
import 'package:apna_pos/features/campaign/mobile/customer_group_details_screen.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_customers_screen.dart';

void main() {
  testWidgets('renders Mobile Customers Screen matching the UI mockup', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MobileCustomersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Top Bar
    expect(find.text('APNA POS'), findsOneWidget);
    expect(find.text('Pizza 47'), findsOneWidget);

    // 2. Title & Subtitle
    expect(find.text('Customers'), findsWidgets);
    expect(
      find.text('Manage customers, groups, loyalty & engagement.'),
      findsOneWidget,
    );

    // 3. 3 Stat Metric Cards
    expect(find.text('Total Customers'), findsOneWidget);
    expect(find.text('12,480'), findsOneWidget);
    expect(find.text('Active Customers'), findsOneWidget);
    expect(find.text('9,860'), findsOneWidget);
    expect(find.text('Loyalty Members'), findsOneWidget);
    expect(find.text('3,420'), findsOneWidget);

    // 4. Pill Tabs: Customers & Groups
    expect(find.text('Customers'), findsWidgets);
    expect(find.text('Groups'), findsOneWidget);

    // 5. Search Bar
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search by name, mobile or group...'), findsOneWidget);

    // 6. Customer Groups section
    expect(find.text('Customer Groups'), findsOneWidget);
    expect(find.text('View All'), findsOneWidget);
    expect(find.text('Pizza Lovers'), findsOneWidget);
    expect(find.text('VIP Customers'), findsOneWidget);
    expect(find.text('Festive Offers'), findsOneWidget);
    expect(find.text('Discount Club'), findsOneWidget);

    // 7. Filter Chips
    expect(find.text('All (12.4K)'), findsOneWidget);
    expect(find.text('Members (3.4K)'), findsOneWidget);
    expect(find.text('VIP (860)'), findsOneWidget);
    expect(find.text('Inactive (120)'), findsOneWidget);

    // 8. Customer List Items
    expect(find.text('Rohit Sharma'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('VIP'), findsWidgets);

    expect(find.text('Ananya Patel'), findsOneWidget);
    expect(find.text('Member'), findsWidgets);

    expect(find.text('Vikram Khanna'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);

    expect(find.text('Aman Kumar'), findsOneWidget);
    expect(find.text('Inactive'), findsWidgets);

    // 9. Floating Action Button
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // 10. Bottom Navigation Bar
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Campaigns'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('renders Create Customer Group Screen matching UI mockup', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateCustomerGroupScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header
    expect(find.text('Create Group'), findsWidgets);

    // 2. Hero Section
    expect(find.text('Create a Customer Group'), findsOneWidget);
    expect(
      find.text('Group your customers to send targeted campaigns and offers.'),
      findsOneWidget,
    );

    // 3. Form Inputs
    expect(find.text('Group Name'), findsOneWidget);
    expect(find.text('Weekend Pizza Offer'), findsOneWidget);

    expect(find.text('Description (Optional)'), findsOneWidget);
    expect(
      find.text('Customers interested in weekend deals and special offers.'),
      findsOneWidget,
    );

    // 4. Add Customers Options
    expect(find.text('Select from Customer List'), findsOneWidget);
    expect(find.text('Add Manually'), findsOneWidget);
    expect(find.text('Import from File (CSV/Excel)'), findsOneWidget);

    // 5. Selected Count Card
    expect(find.text('42 customers selected'), findsOneWidget);

    // 6. Action buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create Group'), findsWidgets);
  });

  testWidgets('renders Customer Group Details Screen matching UI mockup', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final groupData = {
      'id': 'grp_1',
      'name': 'Pizza Lovers',
      'count': 2480,
      'description':
          'Customers who frequently order pizza and are interested in new offers.',
      'createdDate': '12 Oct 2026',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerGroupDetailsScreen(group: groupData),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header
    expect(find.text('Pizza Lovers'), findsWidgets);

    // 2. Top Group Card
    expect(find.text('2,480 Customers'), findsOneWidget);

    // 3. 4 Action Buttons
    expect(find.text('Send\nCampaign'), findsOneWidget);
    expect(find.text('Add\nCustomers'), findsOneWidget);
    expect(find.text('Remove\nCustomers'), findsOneWidget);
    expect(find.text('\nMore'), findsOneWidget);

    // 4. Group Details
    expect(find.text('Group Details'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(
      find.text('Customers who frequently order pizza and are interested in new offers.'),
      findsOneWidget,
    );
    expect(find.text('Created On'), findsOneWidget);
    expect(find.text('12 Oct 2026'), findsOneWidget);
    expect(find.text('Group Members'), findsOneWidget);
    expect(find.text('2,480'), findsOneWidget);
  });
}
