import '../../../core/models/menu_item_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/models/extra_model.dart';
import '../../../core/models/order_model.dart';

class StorefrontBanner {
  final String id;
  final String tag;
  final String headline;
  final String subtitle;
  final String ctaText;
  final String imageUrl;
  final int accentColorHex;

  const StorefrontBanner({
    required this.id,
    required this.tag,
    required this.headline,
    required this.subtitle,
    required this.ctaText,
    required this.imageUrl,
    this.accentColorHex = 0xFFFF5722,
  });

  factory StorefrontBanner.fromJson(Map<String, dynamic> json) {
    return StorefrontBanner(
      id: json['id']?.toString() ?? '',
      tag: json['tag']?.toString() ?? 'SPECIAL OFFER',
      headline: json['headline']?.toString() ?? 'DELICIOUS BITES',
      subtitle: json['subtitle']?.toString() ?? 'Fresh taste crafted with passion',
      ctaText: json['ctaText']?.toString() ?? 'ORDER NOW',
      imageUrl: json['imageUrl']?.toString() ?? '',
      accentColorHex: json['accentColorHex'] as int? ?? 0xFFFF5722,
    );
  }
}

class ProductSizeOption {
  final String id;
  final String name; // e.g., 'Regular', 'Medium', 'Large'
  final String description; // e.g., '7" (1-2 servings)', '10" (2-3 servings)', '12" (3-4 servings)'
  final double price;

  const ProductSizeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
  });
}

class StorefrontAddonItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  bool isSelected;

  StorefrontAddonItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl = '',
    this.isSelected = false,
  });

  StorefrontAddonItem copyWith({bool? isSelected}) {
    return StorefrontAddonItem(
      id: id,
      name: name,
      price: price,
      imageUrl: imageUrl,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class StorefrontCartItem {
  final String uid;
  final MenuItemModel item;
  ProductSizeOption? selectedSize;
  List<StorefrontAddonItem> selectedAddons;
  String instructions;
  int quantity;

  StorefrontCartItem({
    required this.uid,
    required this.item,
    this.selectedSize,
    List<StorefrontAddonItem>? selectedAddons,
    this.instructions = '',
    this.quantity = 1,
  }) : selectedAddons = selectedAddons ?? [];

  double get unitPrice {
    double base = selectedSize != null ? selectedSize!.price : item.effectivePrice;
    double addonsTotal = selectedAddons.where((a) => a.isSelected).fold(0.0, (sum, a) => sum + a.price);
    return base + addonsTotal;
  }

  double get totalPrice => unitPrice * quantity;

  CartItemModel toCartItemModel() {
    final sizeStr = selectedSize != null ? ' (${selectedSize!.name})' : '';
    final addonsStr = selectedAddons.where((a) => a.isSelected).isNotEmpty
        ? ' + [${selectedAddons.where((a) => a.isSelected).map((a) => a.name).join(', ')}]'
        : '';
    final noteCombined = [
      if (sizeStr.isNotEmpty) sizeStr.trim(),
      if (addonsStr.isNotEmpty) addonsStr.trim(),
      if (instructions.trim().isNotEmpty) 'Note: ${instructions.trim()}',
    ].join(' • ');

    final adjustedItem = item.copyWith(
      price: unitPrice,
      salePrice: unitPrice,
      name: '${item.name}$sizeStr',
    );

    return CartItemModel(
      item: adjustedItem,
      quantity: quantity,
      note: noteCombined.isNotEmpty ? noteCombined : null,
    );
  }
}

class StorefrontData {
  final RestaurantModel restaurant;
  final List<String> categories;
  final List<MenuItemModel> menuItems;
  final List<ExtraModel> addOns;
  final List<StorefrontBanner> banners;

  const StorefrontData({
    required this.restaurant,
    required this.categories,
    required this.menuItems,
    required this.addOns,
    required this.banners,
  });
}
