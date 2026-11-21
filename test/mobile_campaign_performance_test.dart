import 'package:flutter/material.dart';
import 'support/campaign_test_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_campaign_data.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_campaign_performance_screen.dart';

CampaignJson _sampleWeekendPizzaCampaign() => {
  'id': 'camp_pizza_1',
  'name': 'Weekend Pizza Offer',
  'status': 'completed',
  'orderTypes': ['takeaway', 'delivery'],
  'channel': {'channelType': 'business_whatsapp'},
  'audience': {'groupName': 'Loyal customers', 'recipientCount': 1240},
  'rewardDetails': {
    'campaignTitle': 'Weekend Pizza Offer',
    'rewardType': 'percentage',
    'discountAmount': 20,
    'minSpendAmount': 499,
    'maxCashbackCap': 150,
    'description': 'Hi {{name}} 🍕\nEnjoy 20% OFF your next order.',
  },
  'couponSettings': {
    'couponCode': 'WEEKEND20',
    'expiryDate': '2026-11-30T23:59:00.000Z',
  },
  'schedule': {
    'sentAt': '2026-11-20T12:30:00.000Z', // 6:00 PM IST
  },
  'template': {
    'category': 'MARKETING',
    'body': 'Hi {{name}} 🍕\nEnjoy 20% OFF your next order.',
  },
  'stats': {
    'totalRecipients': 1240,
    'messagesSent': 1240,
    'delivered': 1180,
    'read': 920,
    'failed': 60,
    'deliveryRate': 95.2,
    'couponOrders': 7,
    'couponRevenue': 1234.5,
  },
};

class _PerformanceApi extends MobileCampaignApi {
  @override
  Future<CampaignJson> performance(String id) async =>
      _sampleWeekendPizzaCampaign();
  @override
  Future<CampaignOptions> options() async => CampaignOptions({
    'groups': [
      {'id': 'loyal', 'name': 'Loyal customers', 'count': 2},
    ],
  });
  @override
  Future<CampaignJson> followUp(String id, CampaignJson payload) async => {
    'count': 2,
    'totalAmount': 2.12,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCampaignTestFonts);
  testWidgets('renders Campaign Performance Overview tab matching UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final campaign = _sampleWeekendPizzaCampaign();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileCampaignPerformanceScreen(
          campaign: campaign,
          api: _PerformanceApi(),
          options: CampaignOptions({'businessName': 'Pizza 47'}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header & Top summary card
    expect(find.text('Campaign performance'), findsWidgets);
    expect(find.text('Weekend Pizza Offer'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.textContaining('WhatsApp · Marketing'), findsOneWidget);

    // 2. Tab pills
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    // 3. 2x2 Metric cards
    expect(find.text('Recipients'), findsOneWidget);
    expect(find.text('1,240'), findsWidgets);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('1,180'), findsOneWidget);
    expect(find.text('Read'), findsWidgets);
    expect(find.text('920'), findsWidgets);
    expect(find.text('Failed'), findsWidgets);
    expect(find.text('60'), findsWidgets);

    // 4. Delivery results card
    expect(find.text('Delivery results'), findsOneWidget);
    expect(find.text('95.2% delivery rate'), findsOneWidget);
    expect(find.text('Delivered, not read'), findsOneWidget);
    expect(find.text('260'), findsOneWidget);
    expect(find.text('Failed to deliver'), findsOneWidget);

    // 5. Coupon stats
    expect(find.text('Coupon orders'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Coupon revenue'), findsOneWidget);
    expect(find.text('₹1,234.5'), findsOneWidget);

    expect(find.byTooltip('More options'), findsNothing);

    // 6. Link card
    expect(find.text('View customer delivery status'), findsOneWidget);

    // 7. Sticky Footer buttons
    expect(find.text('Send to new customers'), findsOneWidget);
    expect(find.text('Resend'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    await tester.tap(find.text('Send to new customers'));
    await tester.pumpAndSettle();
    expect(find.text('Phone numbers'), findsOneWidget);
    expect(find.text('Customer group'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check audience'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 recipients'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resend'));
    await tester.pumpAndSettle();
    expect(find.text('Resend campaign'), findsOneWidget);
    expect(find.text('Failed recipients only'), findsOneWidget);
  });

  testWidgets('renders Campaign Details tab matching UI', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final campaign = _sampleWeekendPizzaCampaign();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileCampaignPerformanceScreen(
          campaign: campaign,
          api: _PerformanceApi(),
          initialTab: 2, // Details tab
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header updates to "Campaign details"
    expect(find.text('Campaign details'), findsWidgets);
    expect(find.text('Coupon active until 30 Nov'), findsOneWidget);

    // 2. Card 1: Campaign information
    expect(find.text('Campaign information'), findsOneWidget);
    expect(find.text('Channel'), findsOneWidget);
    expect(find.text('WhatsApp'), findsWidgets);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Marketing'), findsOneWidget);
    expect(find.text('Audience'), findsOneWidget);
    expect(find.text('Loyal customers'), findsOneWidget);
    expect(find.text('Sent on'), findsOneWidget);
    expect(find.text('Completed at'), findsOneWidget);

    // 3. Card 2: Reward details
    expect(find.text('Reward details'), findsOneWidget);
    expect(find.text('Order type'), findsOneWidget);
    expect(find.text('Takeaway, Delivery'), findsOneWidget);
    expect(find.text('Reward'), findsOneWidget);
    expect(find.text('20% discount'), findsOneWidget);
    expect(find.text('Minimum order'), findsOneWidget);
    expect(find.text('₹499'), findsOneWidget);
    expect(find.text('Maximum discount'), findsOneWidget);
    expect(find.text('₹150'), findsOneWidget);
    expect(find.text('Coupon code'), findsOneWidget);
    expect(find.text('WEEKEND20'), findsOneWidget);
    expect(find.text('Expires'), findsOneWidget);

    // 4. Card 3: Preview snippet
    expect(find.textContaining('Hi {{name}} 🍕'), findsOneWidget);
  });

  testWidgets('switches to Customers tab when tapping link or pill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final campaign = _sampleWeekendPizzaCampaign();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileCampaignPerformanceScreen(
          campaign: campaign,
          api: _PerformanceApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap View customer delivery status
    await tester.ensureVisible(find.text('View customer delivery status'));
    await tester.tap(find.text('View customer delivery status'));
    await tester.pumpAndSettle();

    // Should now be on Customers tab
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Delivered'), findsWidgets);
  });
}
