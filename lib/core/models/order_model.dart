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

  double get totalPrice => item.price * quantity;

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'quantity': quantity,
        'note': note,
      };

  factory CartItemModel.fromJson(Map<String, dynamic> json) => CartItemModel(
        item: MenuItemModel.fromJson(json['item']),
        quantity: json['quantity'] ?? 1,
        note: json['note'],
      );
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
      );

  OrderModel copyWith({
    OrderStatus? status,
    String? paymentMethod,
    String? deliveryAddress,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      tableNumber: tableNumber,
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
    );
  }
}
