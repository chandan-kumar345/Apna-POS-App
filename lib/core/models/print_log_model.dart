import 'order_model.dart';

class PrintLogItemModel {
  final String? productId;
  final String name;
  final double price;
  final int quantity;
  final String foodType;
  final String? note;
  final double totalPrice;

  PrintLogItemModel({
    this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.foodType = 'veg',
    this.note,
    required this.totalPrice,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'foodType': foodType,
        'note': note,
        'totalPrice': totalPrice,
      };

  factory PrintLogItemModel.fromJson(Map<String, dynamic> json) {
    final double rawPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final int qty = (json['quantity'] as num?)?.toInt() ?? 1;
    final double rawTotal = (json['totalPrice'] as num?)?.toDouble() ?? (rawPrice * qty);

    return PrintLogItemModel(
      productId: json['productId']?.toString(),
      name: json['name']?.toString() ?? 'Item',
      price: rawPrice,
      quantity: qty,
      foodType: json['foodType']?.toString() ?? 'veg',
      note: json['note']?.toString(),
      totalPrice: rawTotal,
    );
  }
}

class PrintLogModel {
  final String id;
  final String orderId;
  final String orderNumber;
  final int printNumber;
  final String printType;
  final String orderStatus;
  final String paymentStatus;
  final String paymentMethod;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double tipAmount;
  final double deliveryCharge;
  final double roundOff;
  final double totalAmount;
  final String orderType;
  final String? tableNumber;
  final String? deliveryAddress;
  final String? customerName;
  final String? customerPhone;
  final List<PrintLogItemModel> items;
  final String qrPayload;
  final String qrImageUrl;
  final String invoiceNumber;
  final bool isReprint;
  final String? originalPrintLogId;
  final String printedBy;
  final String notes;
  final String createdAt;

  PrintLogModel({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    this.printNumber = 1,
    this.printType = 'save_and_print',
    this.orderStatus = 'pending',
    this.paymentStatus = 'pending',
    this.paymentMethod = 'unpaid',
    required this.subtotal,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.tipAmount = 0.0,
    this.deliveryCharge = 0.0,
    this.roundOff = 0.0,
    required this.totalAmount,
    this.orderType = 'dineIn',
    this.tableNumber,
    this.deliveryAddress,
    this.customerName,
    this.customerPhone,
    required this.items,
    this.qrPayload = '',
    this.qrImageUrl = '',
    this.invoiceNumber = '',
    this.isReprint = false,
    this.originalPrintLogId,
    this.printedBy = '',
    this.notes = '',
    required this.createdAt,
  });

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isClearCart => printType == 'clear_cart' || printType == 'void' || printType == 'cancelled' || orderStatus == 'cancelled';

  DateTime get createdDateTime {
    final parsed = DateTime.tryParse(createdAt);
    return parsed ?? DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'printNumber': printNumber,
        'printType': printType,
        'orderStatus': orderStatus,
        'paymentStatus': paymentStatus,
        'paymentMethod': paymentMethod,
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'taxAmount': taxAmount,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'tipAmount': tipAmount,
        'deliveryCharge': deliveryCharge,
        'roundOff': roundOff,
        'totalAmount': totalAmount,
        'orderType': orderType,
        'tableNumber': tableNumber,
        'deliveryAddress': deliveryAddress,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items.map((i) => i.toJson()).toList(),
        'qrPayload': qrPayload,
        'qrImageUrl': qrImageUrl,
        'invoiceNumber': invoiceNumber,
        'isReprint': isReprint,
        'originalPrintLogId': originalPrintLogId,
        'printedBy': printedBy,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory PrintLogModel.fromJson(Map<String, dynamic> json) {
    return PrintLogModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      printNumber: (json['printNumber'] as num?)?.toInt() ?? 1,
      printType: json['printType']?.toString() ?? 'save_and_print',
      orderStatus: json['orderStatus']?.toString() ?? 'pending',
      paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      paymentMethod: json['paymentMethod']?.toString() ?? 'unpaid',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
      tipAmount: (json['tipAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      roundOff: (json['roundOff'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      orderType: json['orderType']?.toString() ?? 'dineIn',
      tableNumber: json['tableNumber']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => PrintLogItemModel.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      qrPayload: json['qrPayload']?.toString() ?? '',
      qrImageUrl: json['qrImageUrl']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      isReprint: json['isReprint'] == true,
      originalPrintLogId: json['originalPrintLogId']?.toString(),
      printedBy: json['printedBy']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  /// Converts snapshot to OrderModel for viewing in ReceiptDialog
  OrderModel toOrderModel() {
    return OrderModel(
      id: orderId.isNotEmpty ? orderId : id,
      orderNumber: orderNumber,
      tableNumber: tableNumber,
      orderType: orderType == 'takeaway'
          ? OrderType.takeaway
          : (orderType == 'delivery' ? OrderType.delivery : OrderType.dineIn),
      status: orderStatus == 'completed'
          ? OrderStatus.completed
          : (orderStatus == 'preparing'
              ? OrderStatus.preparing
              : (orderStatus == 'ready'
                  ? OrderStatus.ready
                  : (orderStatus == 'cancelled' ? OrderStatus.cancelled : OrderStatus.pending))),
      paymentStatus: paymentStatus,
      isPaid: isPaid,
      items: items.map((i) => CartItemModel.fromJson({
            'productId': i.productId,
            'name': i.name,
            'price': i.price,
            'quantity': i.quantity,
            'foodType': i.foodType,
            'note': i.note,
          })).toList(),
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      deliveryCharge: deliveryCharge,
      roundOff: roundOff,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      deliveryAddress: deliveryAddress,
      createdAt: createdAt,
      customerName: customerName,
      customerPhone: customerPhone,
      invoiceNumber: invoiceNumber,
      printCount: printNumber,
      qrIntentUrl: qrPayload,
      qrImageUrl: qrImageUrl,
    );
  }
}
