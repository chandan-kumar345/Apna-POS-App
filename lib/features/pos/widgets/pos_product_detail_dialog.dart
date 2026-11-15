import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/utils/ai_nutrition_estimator.dart';
import '../../../core/widgets/food_type_icon.dart';

/// Product presentation only; the register owns the actual cart mutation.
class PosProductDetailDialog extends StatefulWidget {
  final MenuItemModel item;
  final String currency;
  final double defaultGstRate;
  final WidgetBuilder mediaBuilder;
  final void Function(ProductVariant? variant, int quantity) onAdd;

  const PosProductDetailDialog({
    super.key,
    required this.item,
    required this.mediaBuilder,
    required this.onAdd,
    this.currency = '₹',
    this.defaultGstRate = 5,
  });

  @override
  State<PosProductDetailDialog> createState() => _PosProductDetailDialogState();
}

class _PosProductDetailDialogState extends State<PosProductDetailDialog> {
  static const _ink = Color(0xFF172B46);
  static const _muted = Color(0xFF738094);
  static const _line = Color(0xFFE7ECF2);
  static const _blue = Color(0xFF245CD3);
  late ProductVariant? _variant;
  late final ProductNutritionStats _nutrition;
  int _quantity = 1;

  MenuItemModel get _item => widget.item;
  double get _price => _variant?.effectivePrice ?? _item.effectivePrice;
  double get _originalPrice => _variant?.price ?? _item.price;
  bool get _discounted => _variant?.hasDiscount ?? _item.hasDiscount;
  bool get _soldOut =>
      _item.isOutOfStock ||
      (_item.trackInventory && _item.availablePortions <= 0);
  int get _limit => _item.availablePortions > 0 ? _item.availablePortions : 999;
  String _money(double value) =>
      '${widget.currency}${value.toStringAsFixed(0)}';

  @override
  void initState() {
    super.initState();
    _variant = _item.variants.firstOrNull;
    _nutrition = AiNutritionEstimator.estimate(_item);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720;
    return Dialog(
      key: const ValueKey('pos-product-details'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * .9),
        child: SizedBox(
          width: wide ? 720 : 380,
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      key: const ValueKey('product-detail-scroll'),
                      child: wide
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _media(height: 220),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: _details(wide: true)),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _media(
                                  height: ((size.width - 40) / (16 / 9)).clamp(
                                    140,
                                    180,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    10,
                                    14,
                                    10,
                                  ),
                                  child: _details(),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const Divider(height: 1, color: _line),
                  _actions(),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Close product details',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .96),
                    foregroundColor: _ink,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _media({required double height}) => SizedBox(
    height: height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFFF1F4F8),
          child: ClipRect(child: widget.mediaBuilder(context)),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FoodTypeIcon(itemType: _item.itemType, size: 11),
                const SizedBox(width: 5),
                Text(
                  _item.itemType,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_discounted &&
            (_variant?.discountPercent ?? _item.discountPercent) > 0)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(_variant?.discountPercent ?? _item.discountPercent).toStringAsFixed(0)}% off',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _details({bool wide = false}) {
    final gst = _item.gstPercent ?? widget.defaultGstRate;
    final category = [
      _item.category,
      if (_item.subCategory?.trim().isNotEmpty == true) _item.subCategory!,
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(right: wide ? 32 : 0),
          child: Text(
            _item.name,
            key: const ValueKey('product-detail-title'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: _ink,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (category.isNotEmpty)
              Text(
                category,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            _stock(),
          ],
        ),
        if (_item.description.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            _item.description,
            style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.4),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _money(_price),
              key: const ValueKey('product-detail-price'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _ink,
                letterSpacing: -.4,
              ),
            ),
            if (_discounted && _originalPrice > _price)
              Text(
                _money(_originalPrice),
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            Text(
              gst > 0 ? '${gst.toStringAsFixed(0)}% GST' : 'Non-GST',
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
        ),
        if (_item.variants.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Select size',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          _variants(),
        ],
        const SizedBox(height: 10),
        _nutritionCard(),
      ],
    );
  }

  Widget _stock() {
    final low = _item.isLowStock;
    final color = _soldOut
        ? const Color(0xFFB54747)
        : low
        ? const Color(0xFFA66A16)
        : const Color(0xFF268267);
    final stock = _soldOut
        ? 'Out of stock'
        : low
        ? 'Only ${_item.availablePortions} portions left'
        : _item.isStockNotConfigured
        ? 'Stock not tracked'
        : _item.availablePortions > 0
        ? '${_item.availablePortions} portions available'
        : 'Available';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            stock,
            style: TextStyle(fontSize: 10.5, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _variants() => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 240 ||
              MediaQuery.textScalerOf(context).scale(11) > 16
          ? 2
          : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _item.variants.map((v) {
          final selected = _variant == v;
          return SizedBox(
            width: width,
            child: Semantics(
              selected: selected,
              child: OutlinedButton(
                key: ValueKey('product-variant-${v.name}'),
                onPressed: () => setState(() => _variant = v),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: selected ? _blue : _ink,
                  backgroundColor: selected
                      ? const Color(0xFFF0F5FF)
                      : Colors.white,
                  side: BorderSide(color: selected ? _blue : _line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _money(v.effectivePrice),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: selected ? _blue : _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );

  Widget _nutritionCard() => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Nutrition',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const Text(
              'Estimated',
              style: TextStyle(fontSize: 9, color: _muted),
            ),
            Text(
              'Health score ${_nutrition.healthScore}/100',
              style: const TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 228 ||
                    MediaQuery.textScalerOf(context).scale(11) > 16
                ? 2
                : 4;
            final values = [
              ('Calories', '${_nutrition.calories} kcal'),
              ('Protein', '${_nutrition.protein.toStringAsFixed(1)} g'),
              ('Carbs', '${_nutrition.carbs.toStringAsFixed(1)} g'),
              ('Cholesterol', '${_nutrition.cholesterol} mg'),
            ];
            return Wrap(
              runSpacing: 10,
              children: values
                  .map(
                    (v) => SizedBox(
                      width: constraints.maxWidth / columns,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.$1,
                            style: const TextStyle(fontSize: 9, color: _muted),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            v.$2,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (_nutrition.highlights.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _nutrition.highlights.take(3).join(' · '),
            style: const TextStyle(fontSize: 9.5, color: _muted, height: 1.35),
          ),
        ],
      ],
    ),
  );

  Widget _actions() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stepper = DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Decrease quantity',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                onPressed: !_soldOut && _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_rounded, size: 17),
                color: _ink,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: Text(
                  '$_quantity',
                  key: const ValueKey('product-detail-quantity'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Increase quantity',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                onPressed: !_soldOut && _quantity < _limit
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_rounded, size: 17),
                color: _ink,
              ),
            ],
          ),
        );
        final add = FilledButton(
          key: const ValueKey('product-detail-add'),
          onPressed: _soldOut
              ? null
              : () {
                  widget.onAdd(_variant, _quantity);
                  Navigator.of(context).pop();
                },
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _soldOut ? 'Out of stock' : 'Add · ${_money(_price * _quantity)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
        if (constraints.maxWidth < 270 &&
            MediaQuery.textScalerOf(context).scale(12) > 17) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: stepper),
              const SizedBox(height: 10),
              add,
            ],
          );
        }
        return Row(
          children: [
            stepper,
            const SizedBox(width: 12),
            Expanded(child: add),
          ],
        );
      },
    ),
  );
}
