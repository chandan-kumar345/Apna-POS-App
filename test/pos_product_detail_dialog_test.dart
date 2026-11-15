import 'dart:io';
import 'dart:ui' as ui;

import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/features/pos/widgets/pos_product_detail_dialog.dart';
import 'package:apna_pos/features/pos/widgets/pos_product_media_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final item = MenuItemModel(
    id: 'pizza',
    name: 'Chicken Supreme Pizza',
    category: 'Chicken Pizza',
    description:
        'A loaded chicken pizza with peppers, onion, and extra cheese.',
    price: 379,
    itemType: 'Non-Veg',
    availablePortions: 15,
    variants: const [
      ProductVariant(name: 'Regular', price: 379),
      ProductVariant(name: 'Medium', price: 479),
      ProductVariant(name: 'Large', price: 579),
    ],
  );

  setUpAll(() async {
    final dir = Platform.environment['PRODUCT_DETAIL_FONT_DIR'];
    if (dir == null) return;
    final font = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      font.addFont(
        Future.value(
          ByteData.sublistView(File('$dir/$name').readAsBytesSync()),
        ),
      );
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('$dir/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });

  Future<void> open(
    WidgetTester tester, {
    MenuItemModel? product,
    void Function(ProductVariant?, int)? onAdd,
    double scale = 1,
    GlobalKey? capture,
  }) async {
    final photo = Platform.environment['PRODUCT_DETAIL_PHOTO'];
    final image = photo == null
        ? null
        : ResizeImage(FileImage(File(photo).absolute), width: 960);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFFE9EEF5),
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierColor: const Color(0x990D1829),
                    builder: (_) => PosProductDetailDialog(
                      item: product ?? item,
                      onAdd: onAdd ?? (_, _) {},
                      mediaBuilder: (_) => photo == null
                          ? const ColoredBox(
                              color: Color(0xFFDBE4EE),
                              child: Icon(Icons.local_pizza_outlined, size: 48),
                            )
                          : PosProductMediaBox(
                              item: (product ?? item).copyWith(
                                imageUrl: File(photo).absolute.path,
                                images: [],
                                videoUrl: '',
                              ),
                              fit: BoxFit.contain,
                              imageCacheWidth: 960,
                              showDots: false,
                            ),
                    ),
                  ),
                  child: const Text('View product'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (image != null) {
      await tester.runAsync(
        () => precacheImage(
          image,
          tester.element(find.byType(MaterialApp)),
        ),
      );
    }
    await tester.tap(find.text('View product'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selected variant and quantity reach the cart callback exactly once',
    (tester) async {
      ProductVariant? added;
      var quantity = 0;
      var calls = 0;
      await open(
        tester,
        onAdd: (variant, count) {
          added = variant;
          quantity = count;
          calls++;
        },
      );
      await tester.tap(find.byKey(const ValueKey('product-variant-Medium')));
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();
      expect(find.text('Add · ₹958'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('product-detail-add')));
      await tester.pumpAndSettle();
      expect(added, same(item.variants[1]));
      expect(quantity, 2);
      expect(calls, 1);
      expect(find.byType(PosProductDetailDialog), findsNothing);
    },
  );

  testWidgets('stock cap and minimum quantity remain enforced', (tester) async {
    await open(tester, product: item.copyWith(availablePortions: 2));
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.remove_rounded),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Add · ₹758'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pump();
    expect(find.text('Add · ₹379'), findsOneWidget);
  });

  testWidgets('out of stock cannot add; close makes no cart change', (
    tester,
  ) async {
    var calls = 0;
    await open(
      tester,
      product: item.copyWith(availablePortions: 0),
      onAdd: (_, _) => calls++,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('product-detail-add')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Close product details'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(PosProductDetailDialog), findsNothing);
  });

  testWidgets(
    'single price product keeps discount, tax and untracked availability',
    (tester) async {
      ProductVariant? added = item.variants.first;
      await open(
        tester,
        product: item.copyWith(
          variants: [],
          price: 100,
          hasDiscount: true,
          discountPercent: 20,
          salePrice: 80,
          gstPercent: 0,
          trackInventory: false,
          availablePortions: 0,
        ),
        onAdd: (v, _) => added = v,
      );
      expect(find.text('₹80'), findsOneWidget);
      expect(find.text('₹100'), findsOneWidget);
      expect(find.text('Non-GST'), findsOneWidget);
      expect(find.text('20% off'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('product-detail-add')));
      await tester.pumpAndSettle();
      expect(added, isNull);
    },
  );

  for (final config in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(640, 360), 1.0),
    (const Size(1024, 768), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    testWidgets(
      'details scroll while actions stay visible at ${config.$1} scale ${config.$2}',
      (tester) async {
        tester.view.physicalSize = config.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, scale: config.$2);
        final add = find.byKey(const ValueKey('product-detail-add'));
        final before = tester.getRect(add);
        expect(before.bottom, lessThan(config.$1.height));
        expect(before.left, greaterThanOrEqualTo(0));
        await tester.drag(
          find.byKey(const ValueKey('product-detail-scroll')),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(add), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  if (Platform.environment['PRODUCT_DETAIL_CAPTURE_DIR']
      case final String directory) {
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      testWidgets('capture product details at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await open(tester, capture: key);
        if (Platform.environment['PRODUCT_DETAIL_PHOTO'] != null) {
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
        }
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$directory/product-details-${size.width.toInt()}.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
