class ProductVariant {
  final String name;
  final double price;
  final bool hasDiscount;
  final double discountPercent;

  const ProductVariant({
    required this.name,
    required this.price,
    this.hasDiscount = false,
    this.discountPercent = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'hasDiscount': hasDiscount,
        'discountPercent': discountPercent,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        name: json['name'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        hasDiscount: json['hasDiscount'] ?? false,
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      );
}

class MenuItemModel {
  final String id;
  final String name;
  final String category;
  final double price;
  final String description;
  final bool isAvailable;
  final String emoji;
  final String imageUrl;
  final int stockQuantity;
  final String itemType; // 'Veg', 'Non-Veg', 'Egg', 'Beverage'
  final bool hasDiscount;
  final double discountPercent;
  final double? gstPercent; // Optional GST
  final List<ProductVariant> variants;
  final bool trackInventory;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.isAvailable = true,
    this.emoji = '🍔',
    this.imageUrl = '',
    this.stockQuantity = 50,
    this.itemType = 'Veg',
    this.hasDiscount = false,
    this.discountPercent = 0.0,
    this.gstPercent,
    this.variants = const [],
    this.trackInventory = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'description': description,
        'isAvailable': isAvailable,
        'emoji': emoji,
        'imageUrl': imageUrl,
        'stockQuantity': stockQuantity,
        'itemType': itemType,
        'hasDiscount': hasDiscount,
        'discountPercent': discountPercent,
        'gstPercent': gstPercent,
        'variants': variants.map((v) => v.toJson()).toList(),
        'trackInventory': trackInventory,
      };

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    String foodTypeStr = 'Veg';
    if (json['itemType'] != null) {
      foodTypeStr = json['itemType'].toString();
    } else if (json['foodType'] != null) {
      final ft = json['foodType'].toString().toLowerCase();
      if (ft == 'non_veg' || ft == 'non-veg') {
        foodTypeStr = 'Non-Veg';
      } else if (ft == 'egg') {
        foodTypeStr = 'Egg';
      } else {
        foodTypeStr = 'Veg';
      }
    }

    final double rawPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final double rawSalePrice = (json['salePrice'] as num?)?.toDouble() ?? 0.0;
    final bool hasDisc = json['hasDiscount'] == true || (rawSalePrice > 0 && rawSalePrice < rawPrice);

    return MenuItemModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      price: rawPrice,
      description: json['description']?.toString() ?? '',
      isAvailable: json['isAvailable'] ?? true,
      emoji: json['emoji']?.toString() ?? '🍲',
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? '',
      stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? (json['stock'] as num?)?.toInt() ?? 50,
      itemType: foodTypeStr,
      hasDiscount: hasDisc,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (json['gstPercent'] as num?)?.toDouble() ?? (json['taxPercentage'] as num?)?.toDouble(),
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          const [],
      trackInventory: json['trackInventory'] ?? true,
    );
  }

  MenuItemModel copyWith({
    String? name,
    String? category,
    double? price,
    String? description,
    bool? isAvailable,
    String? emoji,
    String? imageUrl,
    int? stockQuantity,
    String? itemType,
    bool? hasDiscount,
    double? discountPercent,
    double? gstPercent,
    List<ProductVariant>? variants,
    bool? trackInventory,
  }) {
    return MenuItemModel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      emoji: emoji ?? this.emoji,
      imageUrl: imageUrl ?? this.imageUrl,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      itemType: itemType ?? this.itemType,
      hasDiscount: hasDiscount ?? this.hasDiscount,
      discountPercent: discountPercent ?? this.discountPercent,
      gstPercent: gstPercent ?? this.gstPercent,
      variants: variants ?? this.variants,
      trackInventory: trackInventory ?? this.trackInventory,
    );
  }
}
