import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/theme/glass_theme.dart';
import 'package:apna_pos/features/campaign/models/campaign_models.dart';
import 'package:apna_pos/features/campaign/services/campaign_service.dart';
import 'package:apna_pos/features/campaign/web/web_campaign_portal_screen.dart';
import 'package:apna_pos/features/campaign/web/views/campaign_dashboard_view.dart';

Map<String, dynamic> campaign(String id, String status) => {
  '_id': id,
  'campaignId': id,
  'name': '$status campaign',
  'status': status,
  'audience': {'recipientCount': 42},
  'channel': <String, dynamic>{},
  'template': <String, dynamic>{},
  'cost': <String, dynamic>{},
  'stats': <String, dynamic>{},
  'createdAt': '2026-11-15T13:02:00Z',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['CAMPAIGN_CAPTURE_DIR'];
  late List<Interceptor> originals;
  var records = <Map<String, dynamic>>[];
  var failCreate = false;
  var creates = 0, autos = 0, groups = 0;
  String? selected;
  var gates = <Completer<List<Map<String, dynamic>>>>[];
  var campaignRequests = 0;
  final requestedStatuses = <String?>[];
  setUpAll(() async {
    if (directory != null) {
      await (FontLoader('CampaignReview')..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    records = [
      campaign('draft-one', 'draft'),
      campaign('running-one', 'running'),
    ];
    failCreate = false;
    creates = 0;
    autos = 0;
    groups = 0;
    selected = null;
    gates = [];
    campaignRequests = 0;
    requestedStatuses.clear();
    final dio = ApiClient().dio;
    originals = List.of(dio.interceptors);
    dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final path = options.uri.path;
            if (options.method == 'POST' && path.endsWith('/campaigns')) {
              if (failCreate) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: options,
                      statusCode: 503,
                    ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': campaign('created-real', 'draft'),
                  },
                ),
              );
              return;
            }
            dynamic data = {};
            if (path.endsWith('/stats'))
              data = {
                'draftCount': 39,
                'approvedCount': 7,
                'scheduledCount': 2,
                'pendingCount': 1,
                'walletBalance': 0,
              };
            else if (path.endsWith('/categories'))
              data = [
                {'label': 'All'},
                {'label': 'Promotional'},
                {'label': 'Free Gift'},
              ];
            else if (path.endsWith('/templates'))
              data = [
                {
                  'id': 'weekend',
                  'name': 'Weekend special',
                  'category': 'Promotional',
                  'tagLabel': 'Promotional',
                  'headerImageUrl': 'assets/images/tpl_food_diwali_pizza.png',
                },
                {
                  'id': 'gift',
                  'name': 'Free dessert gift',
                  'category': 'Free Gift',
                  'tagLabel': 'Free Gift',
                  'headerImageUrl':
                      'assets/images/tpl_food_free_dessert_cake.png',
                },
                {
                  'id': 'menu',
                  'name': 'Discover our new menu',
                  'category': 'New Menu',
                  'headerImageUrl': 'assets/images/tpl_food_new_menu_asian.png',
                },
                {
                  'id': 'bogo',
                  'name': 'Buy 1 get 1 pizza',
                  'category': 'BOGO',
                  'headerImageUrl': 'assets/images/tpl_food_bogo_pizza.png',
                },
              ];
            else if (path.endsWith('/campaigns')) {
              requestedStatuses.add(
                options.queryParameters['status']?.toString(),
              );
              final index = campaignRequests++;
              final list = index > 0 && index - 1 < gates.length
                  ? await gates[index - 1].future
                  : records;
              data = {'campaigns': list};
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: jsonDecode(jsonEncode({'success': true, 'data': data})),
              ),
            );
          },
        ),
      );
  });
  tearDown(() {
    ApiClient().dio.interceptors
      ..clear()
      ..addAll(originals);
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    GlobalKey? key,
    bool portal = false,
  }) async {
    tester.view.physicalSize = Size(width, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dashboard = CampaignDashboardView(
      onCreateCampaign: () => creates++,
      onCreateAutoCampaign: () => autos++,
      onCreateGroup: () => groups++,
      onUseTemplate: (template) => selected = template.id,
      onSelectCampaign: (item) => selected = item.id,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: portal
              ? GlassTheme.themeData
              : ThemeData(
                  useMaterial3: true,
                  fontFamily: directory == null ? null : 'CampaignReview',
                ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.15)),
            child: child!,
          ),
          home: portal
              ? const WebCampaignPortalScreen()
              : Scaffold(body: dashboard),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (directory == null) return;
    await tester.runAsync(() async {
      await Future.wait(
        tester
            .widgetList<Image>(find.byType(Image))
            .map((item) => precacheImage(item.image, key.currentContext!)),
      );
    });
    await tester.pump();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(directory).createSync(recursive: true);
      File(
        '$directory/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 390.0, 1100.0]) {
    testWidgets(
      'campaign studio shows API metrics and zero wallet without overflow at $width',
      (tester) async {
        final key = GlobalKey();
        await mount(tester, width: width, key: key);
        expect(find.text('Campaign performance'), findsOneWidget);
        expect(find.text('39'), findsOneWidget);
        expect(find.text('₹0.00'), findsOneWidget);
        expect(find.text('₹98.95'), findsNothing);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'campaign-studio-${width.toInt()}');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'create, automation, audiences and template actions retain callbacks',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Create new campaign'));
      await tester.tap(find.text('Auto campaigns'));
      await tester.tap(find.text('Audience groups'));
      expect([creates, autos, groups], [1, 1, 1]);
      await scrollTo(tester, find.text('Weekend special'));
      await tester.tap(find.text('Weekend special'));
      expect(selected, 'weekend');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('search filters templates and drafts open the real campaign', (
    tester,
  ) async {
    await mount(tester);
    await scrollTo(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'dessert');
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Free dessert gift'));
    expect(find.text('Weekend special'), findsNothing);
    await tester.tap(find.text('Free dessert gift'));
    expect(selected, 'gift');
    tester.testTextInput.hide();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Drafts (39)'));
    await tester.tap(find.text('Drafts (39)'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('draft campaign'));
    await tester.tap(find.text('draft campaign'));
    expect(selected, 'draft-one');
    expect(requestedStatuses, contains('draft'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'late tab requests cannot overwrite the latest campaign status list',
    (tester) async {
      await mount(tester, width: 1100);
      gates = [Completer(), Completer()];
      await tester.tap(find.text('Drafts (39)'));
      await tester.pump();
      await tester.ensureVisible(find.text('Scheduled (2)'));
      await tester.tap(find.text('Scheduled (2)'));
      await tester.pump();
      gates[1].complete([campaign('scheduled-new', 'scheduled')]);
      await tester.pumpAndSettle();
      gates[0].complete([campaign('draft-old', 'draft')]);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('scheduled campaign'));
      expect(find.text('draft campaign'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('empty performance does not navigate to an invented campaign', (
    tester,
  ) async {
    records = [];
    await mount(tester);
    await tester.tap(find.byTooltip('View campaign performance'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(
      find.text('Create a campaign to view its performance.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'failed campaign creation never fabricates delivered messages or a local success',
    () async {
      failCreate = true;
      final result = await CampaignService().createCampaign(
        name: 'Must fail',
        type: 'marketing',
        audience: const CampaignAudienceModel(recipientCount: 10),
        channel: const CampaignChannelModel(),
        template: const CampaignTemplateModel(id: 'template', name: 'Offer'),
        scheduleMode: 'now',
      );
      expect(result, isNull);
      failCreate = false;
      final saved = await CampaignService().createCampaign(
        name: 'Draft',
        type: 'marketing',
        audience: const CampaignAudienceModel(recipientCount: 10),
        channel: const CampaignChannelModel(),
        template: const CampaignTemplateModel(id: 'template', name: 'Offer'),
        scheduleMode: 'later',
      );
      expect(saved?.id, 'created-real');
    },
  );
  testWidgets('portal isolates dark app theme on light campaign surfaces', (
    tester,
  ) async {
    await mount(tester, portal: true);
    expect(find.text('Campaign studio'), findsOneWidget);
    final context = tester.element(find.byType(CampaignDashboardView));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
