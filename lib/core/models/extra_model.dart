class ExtraModel {
  final String id;
  final String name;
  final String code;
  final String description;
  final String type; // 'coupon', 'discount', 'addon', 'charge', 'tip'
  final String discountType; // 'percent', 'flat'
  final double value;
  final double minOrderAmount;
  final double maxDiscount;
  final double price;
  final int quantity;
  final bool isAvailable;
  final String status;
  final String productId;
  final String variantId;
  final String categoryId;

  ExtraModel({
    required this.id,
    required this.name,
    this.code = '',
    this.description = '',
    this.type = 'coupon',
    this.discountType = 'percent',
    this.value = 0.0,
    this.minOrderAmount = 0.0,
    this.maxDiscount = 0.0,
    this.price = 0.0,
    this.quantity = 1,
    this.isAvailable = true,
    this.status = 'active',
    this.productId = '',
    this.variantId = '',
    this.categoryId = '',
  });

  factory ExtraModel.fromJson(Map<String, dynamic> json) {
    return ExtraModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'coupon',
      discountType: json['discountType']?.toString() ?? 'percent',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (json['maxDiscount'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      isAvailable: json['isAvailable'] == null ? true : json['isAvailable'] == true,
      status: json['status']?.toString() ?? 'active',
      productId: json['productId']?.toString() ?? '',
      variantId: json['variantId']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'type': type,
        'discountType': discountType,
        'value': value,
        'minOrderAmount': minOrderAmount,
        'maxDiscount': maxDiscount,
        'price': price,
        'quantity': quantity,
        'isAvailable': isAvailable,
        'status': status,
        'productId': productId,
        'variantId': variantId,
        'categoryId': categoryId,
      };

  double calculateDiscount(double subtotal) {
    if (subtotal <= 0) return 0.0;
    if (minOrderAmount > 0 && subtotal < minOrderAmount) return 0.0;

    double discount = 0.0;
    if (discountType == 'percent') {
      discount = subtotal * (value / 100.0);
      if (maxDiscount > 0 && discount > maxDiscount) {
        discount = maxDiscount;
      }
    } else {
      discount = value;
    }

    return discount.clamp(0.0, subtotal);
  }
}

class CouponValidationResult {
  final bool isValid;
  final String message;
  final double discountAmount;
  final ExtraModel? extra;

  CouponValidationResult({
    required this.isValid,
    required this.message,
    required this.discountAmount,
    this.extra,
  });

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    return CouponValidationResult(
      isValid: json['isValid'] == true,
      message: json['message']?.toString() ?? '',
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      extra: json['extra'] != null && json['extra'] is Map<String, dynamic>
          ? ExtraModel.fromJson(json['extra'] as Map<String, dynamic>)
          : null,
    );
  }
}
