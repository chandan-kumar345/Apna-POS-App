import 'menu_item_model.dart';

enum OrderType { dineIn, takeaway, delivery }
enum OrderStatus { pending, preparing, ready, completed, cancelled }

class CartItemModel {
  final MenuItemModel item;
  int quantity;
  String? note;

  CartItemModel({
    required this.item,
    this.quantity = 1,
    this.note,
  });

  /// Total price calculated using the effective sale price of the item/variant
  double get totalPrice => item.effectivePrice * quantity;

  /// Original total price before discount
  double get originalTotalPrice => item.price * quantity;

  /// Total discount saved for this line item
  double get discountTotal => (item.price - item.effectivePrice).clamp(0.0, double.infinity) * quantity;

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'quantity': quantity,
        'note': note,
      };

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    if (json['item'] != null && json['item'] is Map) {
      return CartItemModel(
        item: MenuItemModel.fromJson(json['item']),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        note: json['note']?.toString(),
      );
    }
    // Flat item structure returned from backend Order / Sale
    final double rawPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final double rawSale = (json['salePrice'] as num?)?.toDouble() ?? (json['effectivePrice'] as num?)?.toDouble() ?? 0.0;
    final double rawDisc = (json['discountPercent'] as num?)?.toDouble() ?? (json['discount'] as num?)?.toDouble() ?? 0.0;
    final bool hasDisc = json['hasDiscount'] == true || rawDisc > 0 || (rawSale > 0 && rawSale < rawPrice);

    final menuItem = MenuItemModel(
      id: json['productId']?.toString() ?? json['_id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Item',
      category: json['category']?.toString() ?? 'General',
      price: rawPrice,
      salePrice: rawSale > 0 ? rawSale : null,
      hasDiscount: hasDisc,
      discountPercent: rawDisc,
      description: '',
      itemType: json['foodType'] == 'non_veg' ? 'Non-Veg' : json['foodType'] == 'egg' ? 'Egg' : 'Veg',
    );
    return CartItemModel(
      item: menuItem,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      note: json['note']?.toString(),
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String? tableNumber;
  final OrderType orderType;
  final OrderStatus status;
  final List<CartItemModel> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double tipAmount;
  final double deliveryCharge;
  final double roundOff;
  final double totalAmount;
  final String paymentMethod; // Cash, Card, UPI
  final String paymentStatus; // pending, paid
  final bool isPaid;
  final String? deliveryAddress;
  final String createdAt;
  final String? customerName;
  final String? customerPhone;
  final String? invoiceNumber;
  final int printCount;
  final String? qrIntentUrl;
  final String? qrImageUrl;

  OrderModel({
    required this.id,
    required this.orderNumber,
    this.tableNumber,
    this.orderType = OrderType.dineIn,
    this.status = OrderStatus.pending,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    this.discountAmount = 0.0,
    this.tipAmount = 0.0,
    this.deliveryCharge = 0.0,
    this.roundOff = 0.0,
    required this.totalAmount,
    this.paymentMethod = 'UPI',
    this.paymentStatus = 'pending',
    this.isPaid = false,
    this.deliveryAddress,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.invoiceNumber,
    this.printCount = 0,
    this.qrIntentUrl,
    this.qrImageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'tableNumber': tableNumber,
        'orderType': orderType.name,
        'status': status.name,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'discountAmount': discountAmount,
        'tipAmount': tipAmount,
        'deliveryCharge': deliveryCharge,
        'roundOff': roundOff,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'isPaid': isPaid,
        'deliveryAddress': deliveryAddress,
        'createdAt': createdAt,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'invoiceNumber': invoiceNumber,
        'printCount': printCount,
        'qrIntentUrl': qrIntentUrl,
        'qrImageUrl': qrImageUrl,
      };

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawPm = (json['paymentMethod'] ?? 'Cash').toString();
    final rawPs = (json['paymentStatus'] ?? '').toString().toLowerCase();
    final bool rawIsPaid = json['isPaid'] == true || rawPs == 'paid' || json['status'] == 'completed';

    return OrderModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      tableNumber: json['tableNumber']?.toString(),
      orderType: OrderType.values.firstWhere(
        (e) => e.name == (json['orderType']?.toString() ?? ''),
        orElse: () => OrderType.dineIn,
      ),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (json['status']?.toString() ?? ''),
        orElse: () => OrderStatus.pending,
      ),
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => i is Map ? CartItemModel.fromJson(Map<String, dynamic>.from(i)) : null)
              .whereType<CartItemModel>()
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      tipAmount: (json['tipAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      roundOff: (json['roundOff'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: rawPm,
      paymentStatus: rawPs.isNotEmpty ? rawPs : (rawIsPaid ? 'paid' : 'pending'),
      isPaid: rawIsPaid,
      deliveryAddress: json['deliveryAddress']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      printCount: (json['printCount'] as num?)?.toInt() ?? 0,
      qrIntentUrl: json['qrIntentUrl']?.toString(),
      qrImageUrl: json['qrImageUrl']?.toString(),
    );
  }

  /// Helper to safely resolve the exact DateTime of this order
  DateTime get createdDateTime {
    if (createdAt.isNotEmpty) {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed != null) return parsed;
    }
    // Fallback: try parsing orderNumber if formatted with date prefix (e.g. YYYYMMDD-...)
    if (orderNumber.length >= 8) {
      final dStr = orderNumber.substring(0, 8);
      final y = int.tryParse(dStr.substring(0, 4));
      final m = int.tryParse(dStr.substring(4, 6));
      final d = int.tryParse(dStr.substring(6, 8));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.now();
  }

  OrderModel copyWith({
    String? tableNumber,
    OrderStatus? status,
    String? paymentMethod,
    String? paymentStatus,
    bool? isPaid,
    String? deliveryAddress,
    String? customerName,
    String? customerPhone,
    double? roundOff,
    double? totalAmount,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? tipAmount,
    double? deliveryCharge,
    List<CartItemModel>? items,
    String? invoiceNumber,
    int? printCount,
    String? qrIntentUrl,
    String? qrImageUrl,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      orderType: orderType,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      tipAmount: tipAmount ?? this.tipAmount,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      roundOff: roundOff ?? this.roundOff,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isPaid: isPaid ?? this.isPaid,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      createdAt: createdAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      printCount: printCount ?? this.printCount,
      qrIntentUrl: qrIntentUrl ?? this.qrIntentUrl,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
    );
  }
}
