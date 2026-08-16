class InventoryItemModel {
  final String id;
  final String name;
  final String category; // Raw Ingredient, Beverage, Packaging, Dairy
  final double quantity;
  final String unit; // kg, L, pcs, pkts
  final double minThreshold;
  final double costPerUnit;
  final String supplier;

  InventoryItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.minThreshold,
    required this.costPerUnit,
    this.supplier = '',
  });

  double get currentStock => quantity;
  String get supplierName => supplier;

  bool get isLowStock => quantity <= minThreshold;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'minThreshold': minThreshold,
        'costPerUnit': costPerUnit,
        'supplier': supplier,
      };

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) => InventoryItemModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['itemName']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit']?.toString() ?? 'pcs',
        minThreshold: (json['minThreshold'] as num?)?.toDouble() ?? 5.0,
        costPerUnit: (json['costPerUnit'] as num?)?.toDouble() ?? 0.0,
        supplier: json['supplier']?.toString() ?? '',
      );

  InventoryItemModel copyWith({
    String? id,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    double? minThreshold,
    double? costPerUnit,
    String? supplier,
  }) {
    return InventoryItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      minThreshold: minThreshold ?? this.minThreshold,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplier: supplier ?? this.supplier,
    );
  }
}
