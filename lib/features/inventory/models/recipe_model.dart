class RecipeIngredientModel {
  final String materialId;
  final String materialName;
  final double quantity;
  final String unit;
  final double quantityBaseUnits;
  final double preparationLossPercent;
  final double effectiveQuantityBaseUnits;
  final double unitCost;
  final double totalCost;

  RecipeIngredientModel({
    required this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unit,
    required this.quantityBaseUnits,
    this.preparationLossPercent = 0.0,
    required this.effectiveQuantityBaseUnits,
    this.unitCost = 0.0,
    this.totalCost = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'materialId': materialId,
        'materialName': materialName,
        'quantity': quantity,
        'unit': unit,
        'quantityBaseUnits': quantityBaseUnits,
        'preparationLossPercent': preparationLossPercent,
        'effectiveQuantityBaseUnits': effectiveQuantityBaseUnits,
        'unitCost': unitCost,
        'totalCost': totalCost,
      };

  factory RecipeIngredientModel.fromJson(Map<String, dynamic> json) => RecipeIngredientModel(
        materialId: json['materialId']?.toString() ?? '',
        materialName: json['materialName']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit']?.toString() ?? 'g',
        quantityBaseUnits: (json['quantityBaseUnits'] as num?)?.toDouble() ?? 0.0,
        preparationLossPercent: (json['preparationLossPercent'] as num?)?.toDouble() ?? 0.0,
        effectiveQuantityBaseUnits: (json['effectiveQuantityBaseUnits'] as num?)?.toDouble() ?? 0.0,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      );
}

class RecipeModel {
  final String id;
  final String productId;
  final String productName;
  final String recipeName;
  final String variantId;
  final String variantName;
  final double servingSize;
  final String version;
  final List<RecipeIngredientModel> ingredients;
  final double totalFoodCost;
  final double sellingPrice;
  final double foodCostPercentage;
  final bool isActive;
  final String instructions;

  RecipeModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.recipeName = '',
    this.variantId = '',
    this.variantName = '',
    this.servingSize = 1.0,
    this.version = 'v1.0',
    this.ingredients = const [],
    this.totalFoodCost = 0.0,
    this.sellingPrice = 0.0,
    this.foodCostPercentage = 0.0,
    this.isActive = true,
    this.instructions = '',
  });

  double get grossMargin => sellingPrice > totalFoodCost ? sellingPrice - totalFoodCost : 0.0;
  double get marginPercentage => sellingPrice > 0 ? (grossMargin / sellingPrice) * 100 : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'recipeName': recipeName,
        'variantId': variantId,
        'variantName': variantName,
        'servingSize': servingSize,
        'version': version,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'totalFoodCost': totalFoodCost,
        'sellingPrice': sellingPrice,
        'foodCostPercentage': foodCostPercentage,
        'isActive': isActive,
        'instructions': instructions,
      };

  factory RecipeModel.fromJson(Map<String, dynamic> json) => RecipeModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        productId: json['productId']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        recipeName: json['recipeName']?.toString() ?? '',
        variantId: json['variantId']?.toString() ?? '',
        variantName: json['variantName']?.toString() ?? '',
        servingSize: (json['servingSize'] as num?)?.toDouble() ?? 1.0,
        version: json['version']?.toString() ?? 'v1.0',
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) => RecipeIngredientModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        totalFoodCost: (json['totalFoodCost'] as num?)?.toDouble() ?? 0.0,
        sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
        foodCostPercentage: (json['foodCostPercentage'] as num?)?.toDouble() ?? 0.0,
        isActive: json['isActive'] == null ? true : json['isActive'] as bool,
        instructions: json['instructions']?.toString() ?? '',
      );
}
