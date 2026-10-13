class InventoryMovementModel {
  final String id;
  final String materialId;
  final String materialName;
  final String movementType;
  final double quantityDeltaBaseUnits;
  final double balanceBeforeBaseUnits;
  final double balanceAfterBaseUnits;
  final double unitCost;
  final double totalCost;
  final String sourceType;
  final String sourceId;
  final String reason;
  final String createdBy;
  final DateTime createdAt;
  final String baseUnit;

  InventoryMovementModel({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.movementType,
    required this.quantityDeltaBaseUnits,
    required this.balanceBeforeBaseUnits,
    required this.balanceAfterBaseUnits,
    this.unitCost = 0.0,
    this.totalCost = 0.0,
    this.sourceType = 'manual_adjustment',
    this.sourceId = '',
    this.reason = '',
    this.createdBy = 'System',
    required this.createdAt,
    this.baseUnit = '',
  });

  DateTime get timestamp => createdAt;

  bool get isAddition => quantityDeltaBaseUnits > 0;

  String get typeLabel {
    switch (movementType) {
      case 'sale_consumption':
        return 'Sale Consumption';
      case 'purchase_receipt':
        return 'Stock-In (Purchase)';
      case 'stock_out':
        return 'Stock-Out';
      case 'opening_stock':
        return 'Opening Stock';
      case 'inventory_adjustment':
        return 'Physical Count Audit';
      case 'wastage':
        return 'Kitchen Wastage';
      default:
        return movementType;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'materialId': materialId,
        'materialName': materialName,
        'movementType': movementType,
        'quantityDeltaBaseUnits': quantityDeltaBaseUnits,
        'balanceBeforeBaseUnits': balanceBeforeBaseUnits,
        'balanceAfterBaseUnits': balanceAfterBaseUnits,
        'unitCost': unitCost,
        'totalCost': totalCost,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'reason': reason,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'baseUnit': baseUnit,
      };

  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) => InventoryMovementModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        materialId: json['materialId']?.toString() ?? '',
        materialName: json['materialName']?.toString() ?? '',
        movementType: json['movementType']?.toString() ?? 'manual_adjustment',
        quantityDeltaBaseUnits: (json['quantityDeltaBaseUnits'] as num?)?.toDouble() ?? 0.0,
        balanceBeforeBaseUnits: (json['balanceBeforeBaseUnits'] as num?)?.toDouble() ?? 0.0,
        balanceAfterBaseUnits: (json['balanceAfterBaseUnits'] as num?)?.toDouble() ?? 0.0,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
        sourceType: json['sourceType']?.toString() ?? 'manual_adjustment',
        sourceId: json['sourceId']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        createdBy: json['createdBy']?.toString() ?? 'System',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        baseUnit: json['baseUnit']?.toString() ?? json['unit']?.toString() ?? '',
      );
}
