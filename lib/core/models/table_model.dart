enum TableStatus { free, occupied, runningKot, reserved }

class TableModel {
  final String id;
  final int tableNumber;
  final String name;
  final String floor; // Ground Floor, Terrace, Main Hall
  final int capacity;
  final TableStatus status;
  final String? currentOrderId;
  final String? occupiedSince;
  final String? activeOrderNumber;
  final double activeOrderTotal;
  final int activeItemCount;

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.name,
    this.floor = 'Ground Floor',
    this.capacity = 4,
    this.status = TableStatus.free,
    this.currentOrderId,
    this.occupiedSince,
    this.activeOrderNumber,
    this.activeOrderTotal = 0.0,
    this.activeItemCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableNumber': tableNumber,
        'name': name,
        'floor': floor,
        'capacity': capacity,
        'status': status.name,
        'currentOrderId': currentOrderId,
        'occupiedSince': occupiedSince,
        'activeOrderNumber': activeOrderNumber,
        'activeOrderTotal': activeOrderTotal,
        'activeItemCount': activeItemCount,
      };

  factory TableModel.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? '').toString().toLowerCase().trim();
    TableStatus mappedStatus;
    if (statusRaw == 'runningkot' || statusRaw == 'running_kot' || statusRaw == 'billed') {
      mappedStatus = TableStatus.runningKot;
    } else if (statusRaw == 'occupied') {
      mappedStatus = TableStatus.occupied;
    } else if (statusRaw == 'reserved') {
      mappedStatus = TableStatus.reserved;
    } else {
      mappedStatus = TableStatus.free;
    }

    final activeOrder = json['activeOrder'] as Map<String, dynamic>?;
    final cart = json['cart'] as Map<String, dynamic>?;

    final String? orderNum = activeOrder?['orderNumber']?.toString() ?? json['currentOrderNumber']?.toString();
    final double ordTotal = (activeOrder?['totalAmount'] as num?)?.toDouble() ??
        (cart?['totalAmount'] as num?)?.toDouble() ??
        (json['currentOrderTotal'] as num?)?.toDouble() ??
        0.0;
    final int itmCount = (activeOrder?['itemCount'] as num?)?.toInt() ??
        (cart?['itemCount'] as num?)?.toInt() ??
        (json['activeItemCount'] as num?)?.toInt() ??
        0;

    return TableModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      tableNumber: (json['tableNumber'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? 'T-1',
      floor: json['floor']?.toString() ?? 'Ground Floor',
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      status: mappedStatus,
      currentOrderId: activeOrder?['id']?.toString() ?? json['currentOrderId']?.toString(),
      occupiedSince: json['occupiedSince']?.toString(),
      activeOrderNumber: orderNum,
      activeOrderTotal: ordTotal,
      activeItemCount: itmCount,
    );
  }

  TableModel copyWith({
    TableStatus? status,
    String? currentOrderId,
    String? occupiedSince,
    String? activeOrderNumber,
    double? activeOrderTotal,
    int? activeItemCount,
  }) {
    return TableModel(
      id: id,
      tableNumber: tableNumber,
      name: name,
      floor: floor,
      capacity: capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      occupiedSince: occupiedSince ?? this.occupiedSince,
      activeOrderNumber: activeOrderNumber ?? this.activeOrderNumber,
      activeOrderTotal: activeOrderTotal ?? this.activeOrderTotal,
      activeItemCount: activeItemCount ?? this.activeItemCount,
    );
  }
}

/// Helper function to match table names across formats (e.g. 'T-1', 'T1', '1', 'Table 1')
bool isSameTable(String? a, String? b) {
  if (a == null || b == null) return false;
  final cleanA = a.trim().toLowerCase();
  final cleanB = b.trim().toLowerCase();
  if (cleanA.isEmpty || cleanB.isEmpty) return false;
  if (cleanA == cleanB) return true;

  final digitsA = cleanA.replaceAll(RegExp(r'[^0-9]'), '');
  final digitsB = cleanB.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsA.isNotEmpty && digitsA == digitsB) return true;

  if (cleanA == 't-$cleanB' || cleanB == 't-$cleanA') return true;
  if (cleanA == 't$cleanB' || cleanB == 't$cleanA') return true;
  if (cleanA == 'table $cleanB' || cleanB == 'table $cleanA') return true;

  return false;
}
