class CouponTimeSlot {
  final String startTime;
  final String endTime;

  const CouponTimeSlot({required this.startTime, required this.endTime});

  factory CouponTimeSlot.fromJson(Map<String, dynamic> json) {
    return CouponTimeSlot(
      startTime: (json['startTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
      };
}

class CouponModel {
  final String id;
  final String code;
  final String title;
  final String description;
  final String discountType; // 'percentage' | 'flat'
  final double discountValue;
  final double? maxDiscountAmount;
  final double minCartAmount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<String> orderTypes;
  final List<String> applicableCategories;
  final List<String> applicableProducts;
  final List<String> excludedProducts;
  final String customerEligibility; // 'all' | 'new' | 'repeat' | 'min_orders'
  final int customerMinOrders;
  final int usageLimitPerCustomer;
  final int totalUsageLimit;
  final int totalTimesUsed;
  final List<int> validDays; // 0: Sunday, 1: Monday, ..., 6: Saturday
  final List<CouponTimeSlot> timeSlots;
  final List<String> termsAndConditions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CouponModel({
    required this.id,
    required this.code,
    this.title = '',
    this.description = '',
    this.discountType = 'percentage',
    required this.discountValue,
    this.maxDiscountAmount,
    this.minCartAmount = 0.0,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.orderTypes = const ['dineIn', 'takeaway', 'delivery'],
    this.applicableCategories = const [],
    this.applicableProducts = const [],
    this.excludedProducts = const [],
    this.customerEligibility = 'all',
    this.customerMinOrders = 0,
    this.usageLimitPerCustomer = 1,
    this.totalUsageLimit = 0,
    this.totalTimesUsed = 0,
    this.validDays = const [0, 1, 2, 3, 4, 5, 6],
    this.timeSlots = const [],
    this.termsAndConditions = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isPercentage => discountType.toLowerCase() == 'percentage';
  bool get isFlat => !isPercentage;

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  String get formattedDiscount {
    if (isPercentage) {
      final val = discountValue == discountValue.roundToDouble()
          ? discountValue.toStringAsFixed(0)
          : discountValue.toStringAsFixed(1);
      final cap = maxDiscountAmount != null && maxDiscountAmount! > 0
          ? ' up to ₹${maxDiscountAmount!.toStringAsFixed(0)}'
          : '';
      return '$val% OFF$cap';
    } else {
      final val = discountValue == discountValue.roundToDouble()
          ? discountValue.toStringAsFixed(0)
          : discountValue.toStringAsFixed(1);
      return '₹$val FLAT OFF';
    }
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      code: (json['code'] ?? '').toString().toUpperCase(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      discountType: (json['discountType'] ?? 'percentage').toString(),
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toDouble(),
      minCartAmount: (json['minCartAmount'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null,
      isActive: json['isActive'] ?? true,
      orderTypes: (json['orderTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['dineIn', 'takeaway', 'delivery'],
      applicableCategories: (json['applicableCategories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      applicableProducts: (json['applicableProducts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      excludedProducts: (json['excludedProducts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      customerEligibility: (json['customerEligibility'] ?? 'all').toString(),
      customerMinOrders: (json['customerMinOrders'] as num?)?.toInt() ?? 0,
      usageLimitPerCustomer: (json['usageLimitPerCustomer'] as num?)?.toInt() ?? 1,
      totalUsageLimit: (json['totalUsageLimit'] as num?)?.toInt() ?? 0,
      totalTimesUsed: (json['totalTimesUsed'] as num?)?.toInt() ?? 0,
      validDays: (json['validDays'] as List<dynamic>?)
              ?.map((e) => num.tryParse(e.toString())?.toInt() ?? 0)
              .toList() ??
          const [0, 1, 2, 3, 4, 5, 6],
      timeSlots: (json['timeSlots'] as List<dynamic>?)
              ?.map((e) => CouponTimeSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      termsAndConditions: (json['termsAndConditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code.toUpperCase(),
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      if (maxDiscountAmount != null) 'maxDiscountAmount': maxDiscountAmount,
      'minCartAmount': minCartAmount,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      'isActive': isActive,
      'orderTypes': orderTypes,
      'applicableCategories': applicableCategories,
      'applicableProducts': applicableProducts,
      'excludedProducts': excludedProducts,
      'customerEligibility': customerEligibility,
      'customerMinOrders': customerMinOrders,
      'usageLimitPerCustomer': usageLimitPerCustomer,
      'totalUsageLimit': totalUsageLimit,
      'validDays': validDays,
      'timeSlots': timeSlots.map((e) => e.toJson()).toList(),
      'termsAndConditions': termsAndConditions,
    };
  }

  CouponModel copyWith({
    String? id,
    String? code,
    String? title,
    String? description,
    String? discountType,
    double? discountValue,
    double? maxDiscountAmount,
    double? minCartAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<String>? orderTypes,
    List<String>? applicableCategories,
    List<String>? applicableProducts,
    List<String>? excludedProducts,
    String? customerEligibility,
    int? customerMinOrders,
    int? usageLimitPerCustomer,
    int? totalUsageLimit,
    int? totalTimesUsed,
    List<int>? validDays,
    List<CouponTimeSlot>? timeSlots,
    List<String>? termsAndConditions,
  }) {
    return CouponModel(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      minCartAmount: minCartAmount ?? this.minCartAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      orderTypes: orderTypes ?? this.orderTypes,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      applicableProducts: applicableProducts ?? this.applicableProducts,
      excludedProducts: excludedProducts ?? this.excludedProducts,
      customerEligibility: customerEligibility ?? this.customerEligibility,
      customerMinOrders: customerMinOrders ?? this.customerMinOrders,
      usageLimitPerCustomer: usageLimitPerCustomer ?? this.usageLimitPerCustomer,
      totalUsageLimit: totalUsageLimit ?? this.totalUsageLimit,
      totalTimesUsed: totalTimesUsed ?? this.totalTimesUsed,
      validDays: validDays ?? this.validDays,
      timeSlots: timeSlots ?? this.timeSlots,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CouponValidationResult {
  final bool valid;
  final String code;
  final double discountAmount;
  final String discountType;
  final double discountValue;
  final String message;
  final CouponModel? coupon;

  const CouponValidationResult({
    required this.valid,
    this.code = '',
    this.discountAmount = 0.0,
    this.discountType = 'percentage',
    this.discountValue = 0.0,
    this.message = '',
    this.coupon,
  });

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    return CouponValidationResult(
      valid: json['valid'] == true,
      code: (json['code'] ?? '').toString(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountType: (json['discountType'] ?? 'percentage').toString(),
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      message: (json['message'] ?? '').toString(),
      coupon: json['coupon'] != null ? CouponModel.fromJson(json['coupon'] as Map<String, dynamic>) : null,
    );
  }
}

class CouponRedemptionModel {
  final String id;
  final String couponCode;
  final String? orderId;
  final String? customerPhone;
  final String? customerName;
  final double billAmount;
  final double discountAmount;
  final String cashierName;
  final DateTime? createdAt;

  const CouponRedemptionModel({
    required this.id,
    required this.couponCode,
    this.orderId,
    this.customerPhone,
    this.customerName,
    required this.billAmount,
    required this.discountAmount,
    this.cashierName = '',
    this.createdAt,
  });

  factory CouponRedemptionModel.fromJson(Map<String, dynamic> json) {
    return CouponRedemptionModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      couponCode: (json['couponCode'] ?? '').toString(),
      orderId: json['orderId']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerName: json['customerName']?.toString(),
      billAmount: (json['billAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      cashierName: (json['cashierName'] ?? '').toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
