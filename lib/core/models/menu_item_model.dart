class ProductVariant {
  final String name;
  final double price;
  final bool hasDiscount;
  final double discountPercent;
  final double? salePrice;
  final int stock;

  const ProductVariant({
    required this.name,
    required this.price,
    this.hasDiscount = false,
    this.discountPercent = 0.0,
    this.salePrice,
    this.stock = -1,
  });

  double get effectivePrice {
    if (salePrice != null && salePrice! > 0) return salePrice!;
    if (hasDiscount && discountPercent > 0) {
      return price * (1 - discountPercent / 100);
    }
    return price;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'hasDiscount': hasDiscount,
        'discountPercent': discountPercent,
        'salePrice': salePrice ?? (hasDiscount && discountPercent > 0 ? price * (1 - discountPercent / 100) : price),
        'stock': stock,
      };

  factory ProductVariant.fromJson(Map<dynamic, dynamic> json) {
    final double rawPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final double rawSale = (json['salePrice'] as num?)?.toDouble() ?? 0.0;
    final double rawDisc = (json['discountPercent'] as num?)?.toDouble() ?? (json['discount'] as num?)?.toDouble() ?? 0.0;
    final bool hasDisc = json['hasDiscount'] == true || rawDisc > 0 || (rawSale > 0 && rawSale < rawPrice);
    final double? computedSalePrice = rawSale > 0
        ? rawSale
        : (hasDisc && rawDisc > 0 && rawPrice > 0 ? (rawPrice * (1 - rawDisc / 100)) : null);

    return ProductVariant(
      name: (json['name'] ?? '').toString(),
      price: rawPrice,
      hasDiscount: hasDisc,
      discountPercent: rawDisc > 0 ? rawDisc : (rawSale > 0 && rawPrice > 0 ? ((rawPrice - rawSale) / rawPrice * 100) : 0.0),
      salePrice: computedSalePrice,
      stock: (json['stock'] as num?)?.toInt() ?? -1,
    );
  }
}

class MenuItemModel {
  final String id;
  final String productId;
  final String name;
  final String category;
  final double price;
  final double? salePrice;
  final String description;
  final bool isAvailable;
  final String emoji;
  final String imageUrl;
  final List<String> images;
  final String videoUrl;
  final int stockQuantity;
  final String itemType; // 'Veg', 'Non-Veg', 'Egg', 'Beverage'
  final bool hasDiscount;
  final double discountPercent;
  final double? gstPercent; // Optional GST
  final List<ProductVariant> variants;
  final bool trackInventory;

  String get title => name;

  MenuItemModel({
    required this.id,
    String? productId,
    required this.name,
    required this.category,
    required this.price,
    this.salePrice,
    required this.description,
    this.isAvailable = true,
    this.emoji = '🍲',
    this.imageUrl = '',
    this.images = const [],
    this.videoUrl = '',
    this.stockQuantity = 50,
    this.itemType = 'Veg',
    this.hasDiscount = false,
    this.discountPercent = 0.0,
    this.gstPercent,
    this.variants = const [],
    this.trackInventory = true,
  }) : productId = (productId != null && productId.isNotEmpty) ? productId : id;

  double get effectivePrice {
    if (variants.isNotEmpty) {
      return variants.first.effectivePrice;
    }
    if (salePrice != null && salePrice! > 0) return salePrice!;
    if (hasDiscount && discountPercent > 0) {
      return price * (1 - discountPercent / 100);
    }
    return price;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'name': name,
        'title': name,
        'category': category,
        'price': price,
        'salePrice': salePrice ?? (hasDiscount && discountPercent > 0 ? price * (1 - discountPercent / 100) : price),
        'description': description,
        'isAvailable': isAvailable,
        'emoji': emoji,
        'imageUrl': imageUrl,
        'image': imageUrl,
        'images': images.isNotEmpty ? images : (imageUrl.isNotEmpty ? [imageUrl] : []),
        'videoUrl': videoUrl,
        'video': videoUrl,
        'stockQuantity': stockQuantity,
        'stock': stockQuantity,
        'itemType': itemType,
        'foodType': itemType.toLowerCase().replaceAll('-', '_'),
        'hasDiscount': hasDiscount,
        'discountPercent': discountPercent,
        'discount': discountPercent,
        'gstPercent': gstPercent,
        'taxPercentage': gstPercent,
        'variants': variants.map((v) => v.toJson()).toList(),
        'trackInventory': trackInventory,
      };

  factory MenuItemModel.fromJson(Map<dynamic, dynamic> json) {
    String foodTypeStr = 'Veg';
    if (json['itemType'] != null && json['itemType'].toString().isNotEmpty) {
      foodTypeStr = json['itemType'].toString();
    } else if (json['foodType'] != null || json['foodtype'] != null) {
      final ft = (json['foodType'] ?? json['foodtype']).toString().toLowerCase();
      if (ft == 'non_veg' || ft == 'non-veg') {
        foodTypeStr = 'Non-Veg';
      } else if (ft == 'egg') {
        foodTypeStr = 'Egg';
      } else if (ft == 'beverage') {
        foodTypeStr = 'Beverage';
      } else {
        foodTypeStr = 'Veg';
      }
    }

    final double rawPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final double rawSalePrice = (json['salePrice'] as num?)?.toDouble() ?? 0.0;
    final double rawDiscount = (json['discountPercent'] as num?)?.toDouble() ?? (json['discount'] as num?)?.toDouble() ?? 0.0;
    final bool hasDisc = json['hasDiscount'] == true || rawDiscount > 0 || (rawSalePrice > 0 && rawSalePrice < rawPrice);
    final double? computedSalePrice = rawSalePrice > 0
        ? rawSalePrice
        : (hasDisc && rawDiscount > 0 && rawPrice > 0 ? (rawPrice * (1 - rawDiscount / 100)) : null);

    final resolvedId = (json['id'] ?? json['_id'] ?? json['productId'] ?? '').toString();
    final resolvedProductId = (json['productId'] ?? resolvedId).toString();
    final resolvedName = (json['name'] ?? json['title'] ?? '').toString();
    final resolvedImage = (json['imageUrl'] ?? json['image'] ?? '').toString();
    final resolvedVideo = (json['videoUrl'] ?? json['video'] ?? '').toString();

    List<String> imagesList = [];
    if (json['images'] is List) {
      imagesList = (json['images'] as List).map((e) => (e ?? '').toString()).where((s) => s.isNotEmpty).toList();
    }
    if (imagesList.isEmpty && resolvedImage.isNotEmpty) {
      imagesList = [resolvedImage];
    }

    final rawVariants = json['variants'] as List<dynamic>?;
    final List<ProductVariant> parsedVariants = [];
    if (rawVariants != null) {
      for (final v in rawVariants) {
        if (v is Map) {
          parsedVariants.add(ProductVariant.fromJson(v));
        }
      }
    }

    return MenuItemModel(
      id: resolvedId.isNotEmpty ? resolvedId : 'PRD-${DateTime.now().millisecondsSinceEpoch}',
      productId: resolvedProductId.isNotEmpty ? resolvedProductId : resolvedId,
      name: resolvedName,
      category: (json['category'] ?? 'General').toString(),
      price: rawPrice,
      salePrice: computedSalePrice,
      description: (json['description'] ?? '').toString(),
      isAvailable: json['isAvailable'] ?? true,
      emoji: (json['emoji'] ?? '🍲').toString(),
      imageUrl: resolvedImage,
      images: imagesList,
      videoUrl: resolvedVideo,
      stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? (json['stock'] as num?)?.toInt() ?? (json['inventory'] as num?)?.toInt() ?? 50,
      itemType: foodTypeStr,
      hasDiscount: hasDisc,
      discountPercent: rawDiscount > 0 ? rawDiscount : (rawSalePrice > 0 && rawPrice > 0 ? ((rawPrice - rawSalePrice) / rawPrice * 100) : 0.0),
      gstPercent: (json['gstPercent'] as num?)?.toDouble() ?? (json['taxPercentage'] as num?)?.toDouble() ?? (json['gst'] as num?)?.toDouble(),
      variants: parsedVariants,
      trackInventory: json['trackInventory'] ?? true,
    );
  }

  MenuItemModel copyWith({
    String? id,
    String? productId,
    String? name,
    String? category,
    double? price,
    double? salePrice,
    String? description,
    bool? isAvailable,
    String? emoji,
    String? imageUrl,
    List<String>? images,
    String? videoUrl,
    int? stockQuantity,
    String? itemType,
    bool? hasDiscount,
    double? discountPercent,
    double? gstPercent,
    List<ProductVariant>? variants,
    bool? trackInventory,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      salePrice: salePrice ?? this.salePrice,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      emoji: emoji ?? this.emoji,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
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

