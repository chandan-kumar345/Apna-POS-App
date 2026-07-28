class InventoryItemModel {
  final String id;
  final String name;
  final String category; // Raw Ingredient, Beverage, Packaging, Dairy
  final double quantity;
  final String unit; // kg, L, pcs, pkts
  final double minThreshold;
  final double costPerUnit;

  InventoryItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.minThreshold,
    required this.costPerUnit,
  });

  bool get isLowStock => quantity <= minThreshold;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'minThreshold': minThreshold,
        'costPerUnit': costPerUnit,
      };

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) => InventoryItemModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        category: json['category'] ?? 'General',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] ?? 'pcs',
        minThreshold: (json['minThreshold'] as num?)?.toDouble() ?? 5.0,
        costPerUnit: (json['costPerUnit'] as num?)?.toDouble() ?? 0.0,
      );

  InventoryItemModel copyWith({
    double? quantity,
  }) {
    return InventoryItemModel(
      id: id,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit,
      minThreshold: minThreshold,
      costPerUnit: costPerUnit,
    );
  }
}
