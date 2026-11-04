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
  final String? couponCode;
  final String? discountText;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;

  const StorefrontBanner({
    required this.id,
    required this.tag,
    required this.headline,
    required this.subtitle,
    required this.ctaText,
    required this.imageUrl,
    this.accentColorHex = 0xFFFF5722,
    this.couponCode,
    this.discountText,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag': tag,
      'headline': headline,
      'subtitle': subtitle,
      'ctaText': ctaText,
      'imageUrl': imageUrl,
      'accentColorHex': accentColorHex,
      'couponCode': couponCode,
      'discountText': discountText,
      'isActive': isActive,
      'displayOrder': displayOrder,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory StorefrontBanner.fromJson(Map<String, dynamic> json) {
    return StorefrontBanner(
      id: json['id']?.toString() ?? '',
      tag: json['tag']?.toString() ?? 'SPECIAL OFFER',
      headline: json['headline']?.toString() ?? 'DELICIOUS BITES',
      subtitle: json['subtitle']?.toString() ?? 'Fresh taste crafted with passion',
      ctaText: json['ctaText']?.toString() ?? 'ORDER NOW',
      imageUrl: json['imageUrl']?.toString() ?? '',
      accentColorHex: json['accentColorHex'] as int? ?? 0xFFFF5722,
      couponCode: json['couponCode']?.toString(),
      discountText: json['discountText']?.toString(),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  StorefrontBanner copyWith({
    String? id,
    String? tag,
    String? headline,
    String? subtitle,
    String? ctaText,
    String? imageUrl,
    int? accentColorHex,
    String? couponCode,
    String? discountText,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
  }) {
    return StorefrontBanner(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
      ctaText: ctaText ?? this.ctaText,
      imageUrl: imageUrl ?? this.imageUrl,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      couponCode: couponCode ?? this.couponCode,
      discountText: discountText ?? this.discountText,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProductSizeOption {
  final String id;
  final String name; // e.g., 'Regular', 'Medium', 'Large'
  final String description; // e.g., '1-2 servings', '10% OFF'
  final double price;
  final double? originalPrice;
  final double? discountPercent;
  final int stock;

  const ProductSizeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent,
    this.stock = -1,
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

class StorefrontTableInfo {
  final bool isValid;
  final String tableCode;
  final int? tableNumber;
  final String name;
  final String floor;
  final int capacity;
  final int totalTables;
  final String? error;

  const StorefrontTableInfo({
    this.isValid = true,
    required this.tableCode,
    this.tableNumber,
    this.name = '',
    this.floor = 'Ground Floor',
    this.capacity = 4,
    this.totalTables = 0,
    this.error,
  });

  factory StorefrontTableInfo.fromJson(Map<String, dynamic> json) {
    return StorefrontTableInfo(
      isValid: json['isValid'] is bool ? json['isValid'] as bool : true,
      tableCode: json['tableCode']?.toString() ?? '',
      tableNumber: json['tableNumber'] is num
          ? (json['tableNumber'] as num).toInt()
          : int.tryParse(json['tableNumber']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      floor: json['floor']?.toString() ?? 'Ground Floor',
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      totalTables: (json['totalTables'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
    );
  }

  StorefrontTableInfo copyWith({
    bool? isValid,
    String? tableCode,
    int? tableNumber,
    String? name,
    String? floor,
    int? capacity,
    int? totalTables,
    String? error,
  }) {
    return StorefrontTableInfo(
      isValid: isValid ?? this.isValid,
      tableCode: tableCode ?? this.tableCode,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      totalTables: totalTables ?? this.totalTables,
      error: error,
    );
  }
}

class StorefrontData {
  final RestaurantModel restaurant;
  final List<String> categories;
  final List<MenuItemModel> menuItems;
  final List<ExtraModel> addOns;
  final List<StorefrontBanner> banners;
  final bool isOnline;
  final int themeColorHex;
  final int? themeColorEndHex;
  final StorefrontTableInfo? tableInfo;

  const StorefrontData({
    required this.restaurant,
    required this.categories,
    required this.menuItems,
    required this.addOns,
    required this.banners,
    this.isOnline = true,
    this.themeColorHex = 0xFFE65100,
    this.themeColorEndHex,
    this.tableInfo,
  });

  bool get hasGradient => themeColorEndHex != null && themeColorEndHex != themeColorHex;

  StorefrontData copyWith({
    RestaurantModel? restaurant,
    List<String>? categories,
    List<MenuItemModel>? menuItems,
    List<ExtraModel>? addOns,
    List<StorefrontBanner>? banners,
    bool? isOnline,
    int? themeColorHex,
    int? themeColorEndHex,
    StorefrontTableInfo? tableInfo,
  }) {
    return StorefrontData(
      restaurant: restaurant ?? this.restaurant,
      categories: categories ?? this.categories,
      menuItems: menuItems ?? this.menuItems,
      addOns: addOns ?? this.addOns,
      banners: banners ?? this.banners,
      isOnline: isOnline ?? this.isOnline,
      themeColorHex: themeColorHex ?? this.themeColorHex,
      themeColorEndHex: themeColorEndHex ?? this.themeColorEndHex,
      tableInfo: tableInfo ?? this.tableInfo,
    );
  }
}
