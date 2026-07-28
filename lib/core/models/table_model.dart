enum TableStatus { free, occupied, billed, reserved }

class TableModel {
  final String id;
  final int tableNumber;
  final String name;
  final String floor; // Ground Floor, Terrace, Main Hall
  final int capacity;
  final TableStatus status;
  final String? currentOrderId;
  final String? occupiedSince;

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.name,
    this.floor = 'Ground Floor',
    this.capacity = 4,
    this.status = TableStatus.free,
    this.currentOrderId,
    this.occupiedSince,
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
      };

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
        id: json['id'] ?? '',
        tableNumber: json['tableNumber'] ?? 1,
        name: json['name'] ?? 'T-1',
        floor: json['floor'] ?? 'Ground Floor',
        capacity: json['capacity'] ?? 4,
        status: TableStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TableStatus.free,
        ),
        currentOrderId: json['currentOrderId'],
        occupiedSince: json['occupiedSince'],
      );

  TableModel copyWith({
    TableStatus? status,
    String? currentOrderId,
    String? occupiedSince,
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
    );
  }
}
