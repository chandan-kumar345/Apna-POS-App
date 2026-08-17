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
  final double totalAmount;
  final String paymentMethod; // Cash, Card, UPI
  final String? deliveryAddress;
  final String createdAt;
  final String? customerName;
  final String? customerPhone;

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
    required this.totalAmount,
    this.paymentMethod = 'UPI',
    this.deliveryAddress,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
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
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'deliveryAddress': deliveryAddress,
        'createdAt': createdAt,
        'customerName': customerName,
        'customerPhone': customerPhone,
      };

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'] ?? '',
        orderNumber: json['orderNumber'] ?? '',
        tableNumber: json['tableNumber'],
        orderType: OrderType.values.firstWhere(
          (e) => e.name == json['orderType'],
          orElse: () => OrderType.dineIn,
        ),
        status: OrderStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => OrderStatus.pending,
        ),
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => CartItemModel.fromJson(i))
                .toList() ??
            [],
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: json['paymentMethod'] ?? 'Cash',
        deliveryAddress: json['deliveryAddress'],
        createdAt: json['createdAt'] ?? '',
        customerName: json['customerName'],
        customerPhone: json['customerPhone'],
      );

  OrderModel copyWith({
    String? tableNumber,
    OrderStatus? status,
    String? paymentMethod,
    String? deliveryAddress,
    String? customerName,
    String? customerPhone,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      orderType: orderType,
      status: status ?? this.status,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      createdAt: createdAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}
