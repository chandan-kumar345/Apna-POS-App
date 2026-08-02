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

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        category: json['category'] ?? 'General',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] ?? '',
        isAvailable: json['isAvailable'] ?? true,
        emoji: json['emoji'] ?? '🍲',
        imageUrl: json['imageUrl'] ?? '',
        stockQuantity: json['stockQuantity'] ?? 50,
        itemType: json['itemType'] ?? 'Veg',
        hasDiscount: json['hasDiscount'] ?? false,
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
        gstPercent: (json['gstPercent'] as num?)?.toDouble(),
        variants: (json['variants'] as List<dynamic>?)
                ?.map((v) => ProductVariant.fromJson(v))
                .toList() ??
            const [],
        trackInventory: json['trackInventory'] ?? true,
      );

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
