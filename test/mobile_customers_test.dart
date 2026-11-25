import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/services/customer_service.dart';
import 'package:apna_pos/features/campaign/models/campaign_models.dart';
import 'package:apna_pos/features/campaign/mobile/create_customer_group_screen.dart';
import 'package:apna_pos/features/campaign/mobile/customer_group_details_screen.dart';
import 'package:apna_pos/features/campaign/mobile/customer_style.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_campaign_data.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_customers_data.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_customers_screen.dart';

class _Api extends MobileCustomersApi {
  bool failGroups = false, failSave = false, failDelete = false;
  int total = 2408, saves = 0;
  List<Map<String, String>>? savedNumbers;
  String? savedName;
  List<String>? savedCustomer;
  final rows = <AudienceGroupModel>[
    for (final (index, name) in [
      'Weekend offers',
      'VIP customers',
      'Birthday club',
      'Inactive customers',
      'New customers',
      'Regular visitors',
    ].indexed)
      AudienceGroupModel.fromJson({
        'id': 'group-$index',
        'name': name,
        'updatedAt': DateTime.now()
            .subtract(Duration(days: index))
            .toIso8601String(),
        'numbers': [
          for (var i = 0; i < [142, 86, 54, 320, 206, 418][index]; i++)
            {
              'name': 'Contact',
              'phone': '+9198765${i.toString().padLeft(5, '0')}',
            },
        ],
      }),
  ];
  final searches = <String>[];
  final pending = <String, Completer<CustomerDirectoryPage>>{};
  @override
  Future<List<AudienceGroupModel>> groups() async {
    if (failGroups) throw StateError('offline');
    return List.of(rows);
  }

  @override
  Future<CustomerDirectoryPage> customers({
    String search = '',
    int page = 1,
  }) async {
    searches.add(search);
    if (pending.containsKey(search)) return pending[search]!.future;
    final matches =
        [
              CustomerModel(
                id: 'a',
                name: 'Ananya Patel',
                phone: '+919876500001',
                totalOrders: 4,
              ),
              CustomerModel(
                id: 'b',
                name: 'Rohit Sharma',
                phone: '+919876500002',
                totalOrders: 2,
              ),
            ]
            .where(
              (c) => '${c.name} ${c.phone}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
            )
            .toList();
    return CustomerDirectoryPage(
      page > 1
          ? [
              CustomerModel(
                id: 'c',
                name: 'New customer',
                phone: '+919876500003',
              ),
            ]
          : matches,
      search.isEmpty ? total : matches.length,
      page,
    );
  }

  @override
  Future<AudienceGroupModel> group(String id) async =>
      rows.firstWhere((g) => g.id == id);
  @override
  Future<AudienceGroupModel> saveGroup({
    String? id,
    required String name,
    required List<Map<String, String>> numbers,
    String source = 'Manual',
    String description = '',
  }) async {
    saves++;
    savedNumbers = numbers;
    savedName = name;
    if (failSave) throw StateError('offline');
    final result = AudienceGroupModel.fromJson({
      'id': id ?? 'new-group',
      'name': name,
      'numbers': numbers,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    rows.removeWhere((g) => g.id == id);
    rows.insert(0, result);
    return result;
  }

  @override
  Future<void> deleteGroup(String id) async {
    if (failDelete) throw StateError('offline');
    rows.removeWhere((g) => g.id == id);
  }

  @override
  Future<void> saveCustomer(String name, String phone) async {
    if (failSave) throw StateError('offline');
    savedCustomer = [name.trim(), phone];
  }
}

class _Picker extends FilePicker {
  FilePickerResult? result;
  Uint8List? downloaded;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    downloaded = bytes;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  late GlobalKey boundary;
  final options = CampaignOptions({'businessName': 'Pizza 47'});
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final sdk = config.absolute.uri.resolve('${flutter['rootUri']}/');
    final dir = sdk
        .resolve('../../bin/cache/artifacts/material_fonts/')
        .toFilePath();
    final font = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold', 'black']) {
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File('$dir/roboto-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    api = _Api();
    boundary = GlobalKey();
  });

  Future<void> open(
    WidgetTester t,
    Widget screen, {
    Size size = const Size(430, 932),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    final out = Platform.environment['CUSTOMERS_CAPTURES'];
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

  Future<void> tap(WidgetTester t, String text) async {
    final target = find.text(text).last;
    await t.ensureVisible(target);
    await t.tap(target);
    await t.pumpAndSettle();
  }

  Future<void> enter(WidgetTester t, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await t.ensureVisible(field);
    await t.enterText(field, value);
    await t.pumpAndSettle();
  }

  testWidgets(
    'shows real summary, six reference-style groups, search and four navigation items',
    (t) async {
      await open(t, MobileCustomersScreen(api: api, options: options));
      expect(find.text('2,408'), findsOneWidget);
      expect(find.text('Manage customers and their groups.'), findsOneWidget);
      expect(find.text('6 groups'), findsOneWidget);
      expect(find.text('142 numbers'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      await capture(t, 'customers-groups');
      await t.enterText(find.byType(TextField), 'VIP');
      await t.pumpAndSettle();
      expect(find.text('VIP customers'), findsOneWidget);
      expect(find.text('Weekend offers'), findsNothing);
      expect(find.text('1 group'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('empty and failed fetches never invent customer groups', (
    t,
  ) async {
    api.rows.clear();
    api.total = 0;
    await open(t, MobileCustomersScreen(api: api, options: options));
    expect(find.text('Create your first customer group'), findsOneWidget);
    expect(find.text('0 groups'), findsOneWidget);
    api.failGroups = true;
    await tap(t, 'More');
    await tap(t, 'Refresh customers and groups');
    expect(
      find.text('Could not load your groups. Please retry.'),
      findsOneWidget,
    );
    api.failGroups = false;
    await tap(t, 'Retry');
    expect(
      find.text('Could not load your groups. Please retry.'),
      findsNothing,
    );
  });
  testWidgets('all customers uses server search and loads the next page', (
    t,
  ) async {
    api.total = 3;
    await open(t, MobileCustomersScreen(api: api, options: options));
    await tap(t, 'All customers');
    await tap(t, 'Load more customers');
    expect(find.text('New customer'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Ananya');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(api.searches.last, 'Ananya');
    expect(find.text('Ananya Patel'), findsOneWidget);
    expect(find.text('Rohit Sharma'), findsNothing);
    expect(find.text('1 customer'), findsOneWidget);
    await capture(t, 'customers-search');
    expect(t.takeException(), isNull);
  });
  testWidgets('stale customer search responses cannot replace newer results', (
    t,
  ) async {
    await open(t, MobileCustomersScreen(api: api, options: options));
    await tap(t, 'All customers');
    api.pending['old'] = Completer();
    api.pending['new'] = Completer();
    await t.enterText(find.byType(TextField), 'old');
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(find.byType(TextField), 'new');
    await t.pump(const Duration(milliseconds: 300));
    api.pending['new']!.complete(
      CustomerDirectoryPage(
        [
          CustomerModel(
            id: 'new',
            name: 'Latest result',
            phone: '+919876500009',
          ),
        ],
        1,
        1,
      ),
    );
    await t.pumpAndSettle();
    api.pending['old']!.complete(
      CustomerDirectoryPage(
        [
          CustomerModel(
            id: 'old',
            name: 'Stale result',
            phone: '+919876500008',
          ),
        ],
        1,
        1,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Latest result'), findsOneWidget);
    expect(find.text('Stale result'), findsNothing);
  });
  testWidgets(
    'creates a group from entered unique valid numbers and refreshes the list',
    (t) async {
      await open(t, MobileCustomersScreen(api: api, options: options));
      await tap(t, '+ Create group');
      expect(find.text('Build your customer group'), findsOneWidget);
      await enter(t, 'group-title', 'Weekend offers 2');
      await enter(
        t,
        'group-numbers',
        '+919876500001, 00919876500001, +919876500002, bad',
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('check-valid'))).data,
        '2',
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('check-duplicates'))).data,
        '1',
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('check-invalid'))).data,
        '1',
      );
      t.testTextInput.hide();
      await t.pumpAndSettle();
      await capture(t, 'create-group');
      await tap(t, 'Create group');
      expect(api.savedNumbers!.map((n) => n['phone']), [
        '+919876500001',
        '+919876500002',
      ]);
      expect(find.text('7 groups'), findsOneWidget);
      expect(find.text('Weekend offers 2'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('failed create stays open, preserves values and supports retry', (
    t,
  ) async {
    api.failSave = true;
    await open(t, CreateCustomerGroupScreen(api: api));
    await enter(t, 'group-title', 'My group');
    await enter(t, 'group-numbers', '+919876500001');
    await tap(t, 'Create group');
    expect(find.byType(CreateCustomerGroupScreen), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('group-error')));
    await t.pumpAndSettle();
    expect(find.textContaining('Could not save your group'), findsWidgets);
    expect(api.savedName, 'My group');
    expect(api.saves, 1);
    api.failSave = false;
    await tap(t, 'Create group');
    expect(api.saves, 2);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'imports CSV, changes phone column, removes file and downloads a real sample',
    (t) async {
      final picker = _Picker();
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = _Picker());
      final bytes = Uint8List.fromList(
        utf8.encode(
          'Name,Mobile Number,Other\nJane,+919876500001,+919876500002\nJoe,+919876500001,invalid\n',
        ),
      );
      picker.result = FilePickerResult([
        PlatformFile(name: 'customers.csv', size: bytes.length, bytes: bytes),
      ]);
      await open(t, CreateCustomerGroupScreen(api: api));
      await enter(t, 'group-title', 'Imported customers');
      await t.ensureVisible(find.text('Choose file'));
      await t.tap(find.text('Choose file'));
      for (
        var i = 0;
        i < 30 && find.text('customers.csv').evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(find.text('customers.csv'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('check-valid'))).data,
        '1',
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('check-duplicates'))).data,
        '1',
      );
      await t.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await t.tap(find.byType(DropdownButtonFormField<int>));
      await t.pumpAndSettle();
      await tap(t, 'Other');
      expect(
        t.widget<Text>(find.byKey(const ValueKey('check-invalid'))).data,
        '1',
      );
      await capture(t, 'create-group-import');
      await t.ensureVisible(find.byTooltip('Remove imported file'));
      await t.tap(find.byTooltip('Remove imported file'));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('check-valid'))).data,
        '0',
      );
      await tap(t, 'Download sample file');
      expect(utf8.decode(picker.downloaded!), contains('Mobile Number'));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('reviews invalid entries and pastes clipboard contents', (
    t,
  ) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': '+919876500001, invalid'}
          : null,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(t, CreateCustomerGroupScreen(api: api));
    await tap(t, 'Paste');
    expect(find.text('2 numbers entered'), findsOneWidget);
    await tap(t, 'Review invalid numbers');
    expect(find.text('Invalid numbers (1)'), findsOneWidget);
    expect(find.text('invalid'), findsWidgets);
  });
  testWidgets(
    'edits saved group members and only removes a member after a successful save',
    (t) async {
      final group = AudienceGroupModel.fromJson({
        'id': 'group-0',
        'name': 'Weekend offers',
        'numbers': [
          {'name': 'Jane', 'phone': '+919876500001'},
          {'name': 'Joe', 'phone': '+919876500002'},
        ],
      });
      await open(
        t,
        CustomerGroupDetailsScreen(
          api: api,
          group: {'id': group.id, ...group.toJson()},
        ),
      );
      api.failSave = true;
      await t.tap(find.byTooltip('Remove +919876500001'));
      await t.pumpAndSettle();
      await tap(t, 'Remove');
      expect(find.text('+919876500001'), findsOneWidget);
      expect(find.textContaining('Could not remove'), findsOneWidget);
      api.failSave = false;
      await t.tap(find.byTooltip('Remove +919876500001'));
      await t.pumpAndSettle();
      await tap(t, 'Remove');
      expect(find.text('+919876500001'), findsNothing);
      expect(find.text('1 number'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'add customer validates input and keeps failed saves open for retry',
    (t) async {
      await open(t, MobileCustomersScreen(api: api, options: options));
      await tap(t, 'All customers');
      await tap(t, 'Add customer');
      await tap(t, 'Add customer');
      expect(
        find.textContaining('Enter a name and a valid number'),
        findsOneWidget,
      );
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await t.enterText(fields.first, 'Jane');
      await t.enterText(fields.last, '+91 98765 00001');
      api.failSave = true;
      await tap(t, 'Add customer');
      expect(
        find.textContaining('Could not save the customer'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      api.failSave = false;
      await tap(t, 'Add customer');
      expect(api.savedCustomer, ['Jane', '+919876500001']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('group deletion waits for confirmation and server success', (
    t,
  ) async {
    await open(t, MobileCustomersScreen(api: api, options: options));
    await t.tap(find.byTooltip('Options for Weekend offers'));
    await t.pumpAndSettle();
    await tap(t, 'Delete group');
    await tap(t, 'Cancel');
    expect(api.rows.length, 6);
    api.failDelete = true;
    await t.tap(find.byTooltip('Options for Weekend offers'));
    await t.pumpAndSettle();
    await tap(t, 'Delete group');
    await tap(t, 'Delete');
    expect(api.rows.length, 6);
    expect(find.textContaining('Could not delete'), findsOneWidget);
    api.failDelete = false;
    await t.tap(find.byTooltip('Options for Weekend offers'));
    await t.pumpAndSettle();
    await tap(t, 'Delete group');
    await tap(t, 'Delete');
    expect(api.rows.length, 5);
    expect(find.text('5 groups'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 690),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'both screens fit ${size.width} wide with readable scaled text',
      (t) async {
        await open(
          t,
          MobileCustomersScreen(api: api, options: options),
          size: size,
          scale: 1.15,
        );
        expect(t.takeException(), isNull);
        await tap(t, '+ Create group');
        await enter(t, 'group-title', 'My customer group');
        await enter(t, 'group-numbers', '+919876500001');
        t.testTextInput.hide();
        await t.pumpAndSettle();
        await capture(t, 'create-${size.width.toInt()}');
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('customers screen stays fixed when keyboard opens', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);

    t.view.viewInsets = FakeViewPadding.zero;
    await t.pumpWidget(
      MaterialApp(
        home: MobileCustomersScreen(
          api: api,
          options: options,
          showHeader: false,
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    final campaignScaffold = t.widget<Scaffold>(find.byType(Scaffold).last);
    expect(campaignScaffold.resizeToAvoidBottomInset, isFalse);
    final beforeTop = t.getTopLeft(find.text('Create group')).dy;

    t.view.viewInsets = const FakeViewPadding(bottom: 320);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(t.getTopLeft(find.text('Create group')).dy, equals(beforeTop));
    expect(t.takeException(), isNull);

    t.view.viewInsets = FakeViewPadding.zero;
    await t.pumpWidget(
      const MaterialApp(
        home: CustomerShell(
          header: SizedBox(height: 56),
          body: SizedBox.expand(),
          footer: SizedBox(height: 56, child: Text('Pinned Customer Footer')),
        ),
      ),
    );
    await t.pumpAndSettle();

    final customerScaffold = t.widget<Scaffold>(find.byType(Scaffold).last);
    expect(customerScaffold.resizeToAvoidBottomInset, isFalse);
    final beforeFooter = t.getTopLeft(find.text('Pinned Customer Footer')).dy;

    t.view.viewInsets = const FakeViewPadding(bottom: 320);
    await t.pumpAndSettle();

    expect(
      t.getTopLeft(find.text('Pinned Customer Footer')).dy,
      equals(beforeFooter),
    );
    expect(t.takeException(), isNull);
  });
}
