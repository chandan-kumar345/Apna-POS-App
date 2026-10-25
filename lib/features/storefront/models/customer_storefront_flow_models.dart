class CustomerAddressModel {
  final String id;
  final String label; // 'Home', 'Work', 'Other'
  final String fullAddress;
  final String landmark;
  final String pinCode;
  final bool isDefault;

  const CustomerAddressModel({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.landmark = '',
    this.pinCode = '',
    this.isDefault = false,
  });

  CustomerAddressModel copyWith({
    String? id,
    String? label,
    String? fullAddress,
    String? landmark,
    String? pinCode,
    bool? isDefault,
  }) {
    return CustomerAddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      landmark: landmark ?? this.landmark,
      pinCode: pinCode ?? this.pinCode,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'fullAddress': fullAddress,
      'landmark': landmark,
      'pinCode': pinCode,
      'isDefault': isDefault,
    };
  }

  factory CustomerAddressModel.fromJson(Map<String, dynamic> json) {
    return CustomerAddressModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Home',
      fullAddress: json['fullAddress']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      pinCode: json['pinCode']?.toString() ?? '',
      isDefault: json['isDefault'] is bool ? json['isDefault'] as bool : false,
    );
  }
}

class CustomerProfileModel {
  final String id;
  final String phone;
  final String name;
  final String? email;
  final List<CustomerAddressModel> addresses;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const CustomerProfileModel({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    this.addresses = const [],
    this.createdAt,
    this.lastLoginAt,
  });

  CustomerProfileModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    List<CustomerAddressModel>? addresses,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return CustomerProfileModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      addresses: addresses ?? this.addresses,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'addresses': addresses.map((a) => a.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    List<CustomerAddressModel> parsedAddresses = [];
    if (json['addresses'] is List) {
      parsedAddresses = (json['addresses'] as List)
          .whereType<Map>()
          .map((a) => CustomerAddressModel.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    }

    return CustomerProfileModel(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      addresses: parsedAddresses,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.tryParse(json['lastLoginAt'].toString()) : null,
    );
  }
}

class CustomerTimelineStep {
  final String title;
  final String? time;
  final bool isCompleted;
  final bool isActive;

  const CustomerTimelineStep({
    required this.title,
    this.time,
    this.isCompleted = false,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'time': time,
        'isCompleted': isCompleted,
        'isActive': isActive,
      };

  factory CustomerTimelineStep.fromJson(Map<String, dynamic> json) => CustomerTimelineStep(
        title: json['title']?.toString() ?? '',
        time: json['time']?.toString(),
        isCompleted: json['isCompleted'] is bool ? json['isCompleted'] as bool : false,
        isActive: json['isActive'] is bool ? json['isActive'] as bool : false,
      );
}

class CustomerOrderItemSummary {
  final String name;
  final String size;
  final int quantity;
  final double price;
  final List<String> addons;
  final String? instructions;

  const CustomerOrderItemSummary({
    required this.name,
    this.size = '',
    required this.quantity,
    required this.price,
    this.addons = const [],
    this.instructions,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'quantity': quantity,
        'price': price,
        'addons': addons,
        'instructions': instructions,
      };

  factory CustomerOrderItemSummary.fromJson(Map<String, dynamic> json) => CustomerOrderItemSummary(
        name: json['name']?.toString() ?? '',
        size: json['size']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        addons: (json['addons'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        instructions: json['instructions']?.toString(),
      );
}

class CustomerOrderTrackingModel {
  final String orderId;
  final String orderNumber;
  final String restaurantId;
  final String restaurantName;
  final String status; // 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'
  final int currentStepIndex; // 0: Confirmed, 1: Preparing, 2: Out for Delivery, 3: Delivered
  final String estimatedDeliveryMinutes; // e.g. "25 - 35 mins"
  final List<CustomerOrderItemSummary> items;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double grandTotal;
  final String paymentMethod; // 'Cash on Delivery', 'UPI', 'Card', 'Wallets'
  final String paymentStatus; // 'Pending', 'Paid'
  final String deliveryAddress;
  final String deliveryInstructions;
  final DateTime createdAt;

  const CustomerOrderTrackingModel({
    required this.orderId,
    required this.orderNumber,
    required this.restaurantId,
    required this.restaurantName,
    required this.status,
    required this.currentStepIndex,
    this.estimatedDeliveryMinutes = '25 - 35 mins',
    this.items = const [],
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    this.discount = 0.0,
    required this.grandTotal,
    required this.paymentMethod,
    this.paymentStatus = 'Pending',
    required this.deliveryAddress,
    this.deliveryInstructions = '',
    required this.createdAt,
  });

  List<CustomerTimelineStep> get timelineSteps {
    return [
      CustomerTimelineStep(
        title: 'Order Confirmed',
        time: '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
        isCompleted: currentStepIndex >= 0,
        isActive: currentStepIndex == 0,
      ),
      CustomerTimelineStep(
        title: 'Preparing Your Food',
        time: currentStepIndex >= 1
            ? '${createdAt.add(const Duration(minutes: 5)).hour.toString().padLeft(2, '0')}:${createdAt.add(const Duration(minutes: 5)).minute.toString().padLeft(2, '0')}'
            : null,
        isCompleted: currentStepIndex >= 1,
        isActive: currentStepIndex == 1,
      ),
      CustomerTimelineStep(
        title: 'Out for Delivery',
        time: currentStepIndex >= 2
            ? '${createdAt.add(const Duration(minutes: 20)).hour.toString().padLeft(2, '0')}:${createdAt.add(const Duration(minutes: 20)).minute.toString().padLeft(2, '0')}'
            : null,
        isCompleted: currentStepIndex >= 2,
        isActive: currentStepIndex == 2,
      ),
      CustomerTimelineStep(
        title: 'Delivered',
        time: currentStepIndex >= 3
            ? '${createdAt.add(const Duration(minutes: 32)).hour.toString().padLeft(2, '0')}:${createdAt.add(const Duration(minutes: 32)).minute.toString().padLeft(2, '0')}'
            : null,
        isCompleted: currentStepIndex >= 3,
        isActive: currentStepIndex == 3,
      ),
    ];
  }

  CustomerOrderTrackingModel copyWith({
    String? orderId,
    String? orderNumber,
    String? restaurantId,
    String? restaurantName,
    String? status,
    int? currentStepIndex,
    String? estimatedDeliveryMinutes,
    List<CustomerOrderItemSummary>? items,
    double? subtotal,
    double? deliveryFee,
    double? tax,
    double? discount,
    double? grandTotal,
    String? paymentMethod,
    String? paymentStatus,
    String? deliveryAddress,
    String? deliveryInstructions,
    DateTime? createdAt,
  }) {
    return CustomerOrderTrackingModel(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'status': status,
        'currentStepIndex': currentStepIndex,
        'estimatedDeliveryMinutes': estimatedDeliveryMinutes,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'tax': tax,
        'discount': discount,
        'grandTotal': grandTotal,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'deliveryAddress': deliveryAddress,
        'deliveryInstructions': deliveryInstructions,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomerOrderTrackingModel.fromJson(Map<String, dynamic> json) {
    List<CustomerOrderItemSummary> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .whereType<Map>()
          .map((i) => CustomerOrderItemSummary.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    }

    return CustomerOrderTrackingModel(
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'confirmed',
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      estimatedDeliveryMinutes: json['estimatedDeliveryMinutes']?.toString() ?? '25 - 35 mins',
      items: parsedItems,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'Cash on Delivery',
      paymentStatus: json['paymentStatus']?.toString() ?? 'Pending',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      deliveryInstructions: json['deliveryInstructions']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
