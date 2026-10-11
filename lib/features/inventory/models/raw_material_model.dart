class RawMaterialModel {
  final String id;
  final String sku;
  final String name;
  final String category;
  final String baseUnit; // 'g', 'ml', 'pcs'
  final String purchaseUnit; // 'kg', 'L', 'pcs', 'box', 'bag', 'pack'
  final double conversionFactor; // baseUnits per purchaseUnit
  final double minimumStock;
  final double currentStock;
  final double averageUnitCost; // per purchaseUnit
  final double costPerBaseUnit;
  final String preferredSupplier;
  final String inventoryMode; // 'automatic', 'manual'
  final bool isActive;
  final String notes;

  RawMaterialModel({
    required this.id,
    required this.sku,
    required this.name,
    this.category = 'General',
    this.baseUnit = 'g',
    this.purchaseUnit = 'kg',
    this.conversionFactor = 1000.0,
    this.minimumStock = 0.0,
    this.currentStock = 0.0,
    this.averageUnitCost = 0.0,
    this.costPerBaseUnit = 0.0,
    this.preferredSupplier = '',
    this.inventoryMode = 'automatic',
    this.isActive = true,
    this.notes = '',
  });

  bool get isOutOfStock => currentStock <= 0;
  bool get isLowStock => currentStock > 0 && currentStock <= minimumStock;
  double get valuation => currentStock * costPerBaseUnit;

  String get formattedStock {
    if (baseUnit == 'g') {
      if (currentStock >= 1000) {
        final kg = currentStock / 1000;
        return '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 2)} kg (${currentStock.toStringAsFixed(0)} g)';
      }
      return '${currentStock.toStringAsFixed(0)} g';
    } else if (baseUnit == 'ml') {
      if (currentStock >= 1000) {
        final l = currentStock / 1000;
        return '${l.toStringAsFixed(l % 1 == 0 ? 0 : 2)} L (${currentStock.toStringAsFixed(0)} ml)';
      }
      return '${currentStock.toStringAsFixed(0)} ml';
    }
    return '${currentStock.toStringAsFixed(currentStock % 1 == 0 ? 0 : 1)} $baseUnit';
  }

  String get formattedMinStock {
    if (baseUnit == 'g' && minimumStock >= 1000) {
      final kg = minimumStock / 1000;
      return '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1)} kg';
    }
    if (baseUnit == 'ml' && minimumStock >= 1000) {
      final l = minimumStock / 1000;
      return '${l.toStringAsFixed(l % 1 == 0 ? 0 : 1)} L';
    }
    return '${minimumStock.toStringAsFixed(minimumStock % 1 == 0 ? 0 : 1)} $baseUnit';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'category': category,
        'baseUnit': baseUnit,
        'purchaseUnit': purchaseUnit,
        'conversionFactor': conversionFactor,
        'minimumStock': minimumStock,
        'currentStock': currentStock,
        'averageUnitCost': averageUnitCost,
        'costPerBaseUnit': costPerBaseUnit,
        'preferredSupplier': preferredSupplier,
        'inventoryMode': inventoryMode,
        'isActive': isActive,
        'notes': notes,
      };

  factory RawMaterialModel.fromJson(Map<String, dynamic> json) => RawMaterialModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
        baseUnit: json['baseUnit']?.toString() ?? 'g',
        purchaseUnit: json['purchaseUnit']?.toString() ?? 'kg',
        conversionFactor: (json['conversionFactor'] as num?)?.toDouble() ?? 1000.0,
        minimumStock: (json['minimumStock'] as num?)?.toDouble() ?? 0.0,
        currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0.0,
        averageUnitCost: (json['averageUnitCost'] as num?)?.toDouble() ?? 0.0,
        costPerBaseUnit: (json['costPerBaseUnit'] as num?)?.toDouble() ?? 0.0,
        preferredSupplier: json['preferredSupplier']?.toString() ?? '',
        inventoryMode: json['inventoryMode']?.toString() ?? 'automatic',
        isActive: json['isActive'] == null ? true : json['isActive'] as bool,
        notes: json['notes']?.toString() ?? '',
      );

  RawMaterialModel copyWith({
    String? id,
    String? sku,
    String? name,
    String? category,
    String? baseUnit,
    String? purchaseUnit,
    double? conversionFactor,
    double? minimumStock,
    double? currentStock,
    double? averageUnitCost,
    double? costPerBaseUnit,
    String? preferredSupplier,
    String? inventoryMode,
    bool? isActive,
    String? notes,
  }) {
    return RawMaterialModel(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      baseUnit: baseUnit ?? this.baseUnit,
      purchaseUnit: purchaseUnit ?? this.purchaseUnit,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      minimumStock: minimumStock ?? this.minimumStock,
      currentStock: currentStock ?? this.currentStock,
      averageUnitCost: averageUnitCost ?? this.averageUnitCost,
      costPerBaseUnit: costPerBaseUnit ?? this.costPerBaseUnit,
      preferredSupplier: preferredSupplier ?? this.preferredSupplier,
      inventoryMode: inventoryMode ?? this.inventoryMode,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}
