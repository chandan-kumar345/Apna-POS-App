import 'support/campaign_test_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/coupon_model.dart';
import 'package:apna_pos/features/campaign/mobile/campaign_editor.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_campaign_dashboard.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_campaign_data.dart';

const photo = 'https://images.example.test/menu.jpg';
final choices = CampaignOptions({
  'businessName': 'Pizza 47',
  'channels': [
    {'id': 'business_whatsapp', 'name': 'Pizza 47', 'connected': true},
  ],
  'products': [
    {'id': 'pizza', 'name': 'Regular Margherita'},
    {'id': 'bread', 'name': 'Garlic bread'},
  ],
  'groups': [
    {'id': 'loyal', 'name': 'Loyal customers', 'count': 1240},
  ],
});
CampaignJson record(String id, String title, String reward, String status) => {
  'id': id,
  'name': title,
  'status': status,
  'orderTypes': ['takeaway', 'delivery'],
  'mobileStudio': {'revision': 1, 'groupId': 'loyal'},
  'channel': {'channelType': 'business_whatsapp'},
  'rewardDetails': {
    'campaignTitle': title,
    'rewardType': reward,
    'discountAmount': reward == 'percentage' ? 20 : 100,
    'minSpendAmount': 499,
    'maxCashbackCap': 150,
  },
  'couponSettings': {
    'couponCode': 'WEEKEND20',
    'expiryDate': DateTime.now()
        .add(const Duration(days: 10))
        .toIso8601String(),
  },
  'audience': {'recipientCount': 1240},
  'template': {
    'category': 'MARKETING',
    'body':
        'Hi {{name}} 👋\nEnjoy 20% OFF your next order.\nUse WEEKEND20 · Min. ₹499\nSave up to ₹150.',
    'headerMediaUrl': photo,
    'actions': [
      {
        'type': 'URL',
        'text': 'Order now',
        'value': 'https://pizza47.example/order',
      },
      {'type': 'PHONE_NUMBER', 'text': 'Call store', 'value': '+919876543210'},
    ],
  },
  'schedule': {'mode': 'now'},
  'cost': <String, dynamic>{},
  'stats': <String, dynamic>{},
};

class _Api extends MobileCampaignApi {
  List<CampaignJson> rows = [
    record('a', 'Weekend Pizza Offer', 'percentage', 'scheduled'),
    record('b', 'Lunch Treat', 'flat_discount', 'completed'),
    record('c', 'Buy One, Get One', 'bogo', 'draft'),
  ];
  CampaignJson? last;
  int sends = 0, submissions = 0;
  @override
  Future<CampaignOptions> options() async => choices;
  @override
  Future<CampaignJson> dashboard(String search, String status, int page) async {
    final matches = rows
        .where(
          (r) =>
              (status == 'all' || r['status'] == status) &&
              r['name'].toString().toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return {
      'campaigns': matches,
      'total': matches.length,
      'sent': 12400,
      'read': 9722,
    };
  }

  @override
  Future<CampaignJson> save(MobileCampaignDraft draft) async {
    last = draft.toJson();
    return {
      'mobileStudio': {'revision': draft.revision + 1},
    };
  }

  @override
  Future<void> submit(MobileCampaignDraft draft) async {
    submissions++;
  }

  @override
  Future<CampaignJson> launch(MobileCampaignDraft draft, int count) async {
    sends++;
    return {'status': 'scheduled'};
  }
}

void main() {
  test('POS uses the server-confirmed campaign discount and eligibility', () {
    final result = CouponValidationResult.fromJson({
      'success': true,
      'data': {
        'valid': true,
        'discountAmount': 150,
        'coupon': {
          'code': 'WEEKEND20',
          'discountType': 'percentage',
          'discountValue': 20,
          'campaignId': 'campaign',
        },
      },
    });
    expect(result.valid, isTrue);
    expect(result.code, 'WEEKEND20');
    expect(result.campaignManaged, isTrue);
    expect(result.discountAmount, 150);
    final declined = CouponValidationResult.fromJson({
      'success': false,
      'data': {'valid': false, 'campaignManaged': true},
    });
    expect(declined.valid, isFalse);
    expect(declined.campaignManaged, isTrue);
    expect(
      CouponValidationResult.fromJson({'valid': true, 'code': 'OLD'}).code,
      'OLD',
    );
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['CAMPAIGN_MOBILE_CAPTURES'];
  late _Api api;
  late GlobalKey boundary;
  setUpAll(loadCampaignTestFonts);
  setUp(() {
    api = _Api();
    boundary = GlobalKey();
  });
  Future<void> open(
    WidgetTester t,
    Widget child, {
    Size size = const Size(390, 760),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final image = await t.runAsync(() async {
      final bytes = await rootBundle.load(
        'assets/images/tpl_food_bogo_pizza.png',
      );
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: 400,
      );
      return (await codec.getNextFrame()).image;
    });
    PaintingBinding.instance.imageCache.putIfAbsent(
      const NetworkImage(photo),
      () =>
          OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))),
    );
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (out == null) return;
    await t.pump();
    await t.runAsync(() async {
      final png =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
      final bytes = await png.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory(out)..createSync(recursive: true);
      await File(
        '${dir.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      png.dispose();
    });
  }

  Future<void> tap(WidgetTester t, String name) async {
    final f = find.text(name).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> enter(WidgetTester t, String label, String value) async {
    final f = find.byKey(ValueKey(label)).last;
    await t.ensureVisible(f);
    await t.enterText(f, value);
    await t.pump();
  }

  testWidgets('dashboard uses real filters and opens all five reward forms', (
    t,
  ) async {
    await open(t, MobileCampaignDashboard(api: api));
    await capture(t, 'dashboard');
    await t.tap(find.text('Completed').first);
    await t.pumpAndSettle();
    expect(find.text('Lunch Treat'), findsOneWidget);
    expect(find.text('Weekend Pizza Offer'), findsNothing);
    await tap(t, 'All');
    await tap(t, 'Create campaign');
    await tap(t, 'Select reward type');
    await capture(t, 'choose-reward');
    for (final label in [
      'Percentage',
      'Flat discount',
      'Free gift',
      'BOGO',
      'Promotional',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tap(t, 'Flat discount');
    await enter(t, 'Discount amount (₹)', '100');
    await enter(t, 'Minimum order (₹)', '599');
    await enter(t, 'Coupon code', 'flat100');
    await tap(t, 'Next');
    expect(find.text('Campaign message'), findsOneWidget);
    await t.tap(find.byTooltip('Save draft'));
    await t.pumpAndSettle();
    expect(api.last, containsPair('rewardType', 'flat_discount'));
    expect(api.last, containsPair('couponCode', 'FLAT100'));
    expect(api.sends, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'submitting a template preserves the image and buttons without sending messages',
    (t) async {
      final draft = MobileCampaignDraft.fromJson(api.rows.first);
      await open(t, CampaignEditor(api: api, options: choices, draft: draft));
      await capture(t, 'percentage');
      await tap(t, 'Next');
      await capture(t, 'message');
      await tap(t, 'Next: Actions');
      expect(find.text('Primary action'), findsOneWidget);
      await capture(t, 'actions');
      await tap(t, 'Review campaign');
      await capture(t, 'review');
      expect(find.text('Send campaign'), findsNothing);
      await tap(t, 'Submit for review');
      expect(api.submissions, 1);
      expect(api.sends, 0);
      expect(api.last!['actions'], hasLength(2));
      expect(api.last!['imageUrl'], photo);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a local call number and quick reply enable Review campaign', (
    t,
  ) async {
    final draft = MobileCampaignDraft.fromJson(api.rows.first)
      ..actions = [
        MessageAction(type: 'PHONE_NUMBER', text: 'Call Now'),
        MessageAction(type: 'QUICK_REPLY', text: 'DONE'),
      ];
    await open(t, CampaignEditor(api: api, options: choices, draft: draft));
    await tap(t, 'Next');
    await tap(t, 'Next: Actions');
    await enter(t, 'Phone number', '97095');
    expect(find.textContaining('10-digit Indian mobile'), findsOneWidget);
    await enter(t, 'Phone number', '9709593705');
    expect(find.textContaining('10-digit Indian mobile'), findsNothing);
    await tap(t, 'Review campaign');
    expect(find.text('Submit for review'), findsOneWidget);
    expect(draft.actions.first.toJson()['value'], '+919709593705');
    draft.actions.first.value = '+44 7700 900123';
    expect(draft.actions.first.error, isNull);
    expect(draft.actions.first.toJson()['value'], '+447700900123');
  });

  testWidgets(
    'an approval received while the dashboard is covered appears on return',
    (t) async {
      api.rows = [record('a', 'Lunch offer', 'percentage', 'in_review')];
      await open(t, MobileCampaignDashboard(api: api));
      final navigator = t.state<NavigatorState>(find.byType(Navigator).first);
      navigator.push<void>(MaterialPageRoute(builder: (_) => const Scaffold()));
      await t.pumpAndSettle();
      api.rows = [record('a', 'Lunch offer', 'percentage', 'approved')];
      await t.pump(const Duration(seconds: 31));
      navigator.pop();
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 31));
      await t.pumpAndSettle();
      expect(find.text('Send to customers'), findsOneWidget);
      expect(api.sends, 0);
    },
  );

  testWidgets(
    'approved campaign has a separate audience, opt-in and send decision',
    (t) async {
      api.rows.first['status'] = 'approved';
      await open(t, MobileCampaignDashboard(api: api));
      await tap(t, 'Send to customers');
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Send campaign'),
            )
            .onPressed,
        isNull,
      );
      await tap(t, 'Schedule');
      expect(find.text('Choose sending time (IST)'), findsOneWidget);
      await tap(t, 'Send now');
      await t.ensureVisible(find.byType(Checkbox));
      await t.tap(find.byType(Checkbox));
      await t.pumpAndSettle();
      await capture(t, 'approved-send');
      await tap(t, 'Send campaign');
      expect(api.sends, 1);
      expect(api.submissions, 0);
      expect(api.last, isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'auth can submit its preset template without an audience send on a narrow phone',
    (t) async {
      final draft = MobileCampaignDraft.fromJson(api.rows.first)
        ..category = 'AUTHENTICATION';
      await open(
        t,
        CampaignEditor(api: api, options: choices, draft: draft),
        size: const Size(320, 650),
      );
      await tap(t, 'Next');
      expect(find.textContaining('verification codes'), findsOneWidget);
      await tap(t, 'Next: Actions');
      await tap(t, 'Review campaign');
      expect(find.text('Send campaign'), findsNothing);
      await tap(t, 'Submit for review');
      expect(api.submissions, 1);
      expect(api.sends, 0);
      expect(t.takeException(), isNull);
    },
  );

  for (final kind in ['flat_discount', 'free_gift', 'bogo', 'promotional']) {
    testWidgets('shows only the configured $kind fields and live summary', (
      t,
    ) async {
      final d = MobileCampaignDraft.fromJson(api.rows.first)
        ..reward = kind
        ..gift = 'bread'
        ..buy = 'pizza'
        ..headline = 'Live Music Night'
        ..details = 'Join us for live music and your favourite pizzas.'
        ..terms = 'Dine-in only · 7–10 PM';
      if (kind == 'flat_discount') {
        d.amount = '100';
        d.minimum = '599';
        d.coupon = 'FLAT100';
      }
      if (kind == 'free_gift') {
        d.minimum = '799';
        d.coupon = 'FREEGIFT';
        d.orders = ['delivery'];
      }
      if (kind == 'bogo') {
        d.gift = 'pizza';
        d.coupon = 'PIZZAPLUS1';
        d.orders = ['dine_in', 'takeaway'];
      }
      if (kind == 'promotional') {
        d.coupon = 'MUSICNIGHT';
        d.orders = ['dine_in'];
      }
      await open(t, CampaignEditor(api: api, options: choices, draft: d));
      expect(find.byKey(const ValueKey('Discount (%)')), findsNothing);
      expect(find.text(d.summary(choices)), findsOneWidget);
      if (kind == 'free_gift') {
        await t.tap(find.byTooltip('Increase Gift quantity'));
        await t.pump();
        expect(d.giftQty, 2);
      }
      await capture(t, kind);
      expect(t.takeException(), isNull);
    });
  }
}
