class MenuItemModel {
  final String id;
  final String name;
  final String category;
  final double price;
  final String description;
  final bool isAvailable;
  final String emoji;
  final String imageUrl;
  final int stockQuantity;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.isAvailable = true,
    this.emoji = '🍔',
    this.imageUrl = '',
    this.stockQuantity = 50,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'description': description,
        'isAvailable': isAvailable,
        'emoji': emoji,
        'imageUrl': imageUrl,
        'stockQuantity': stockQuantity,
      };

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        category: json['category'] ?? 'General',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] ?? '',
        isAvailable: json['isAvailable'] ?? true,
        emoji: json['emoji'] ?? '🍲',
        imageUrl: json['imageUrl'] ?? '',
        stockQuantity: json['stockQuantity'] ?? 50,
      );

  MenuItemModel copyWith({
    String? name,
    String? category,
    double? price,
    String? description,
    bool? isAvailable,
    String? emoji,
    String? imageUrl,
    int? stockQuantity,
  }) {
    return MenuItemModel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      emoji: emoji ?? this.emoji,
      imageUrl: imageUrl ?? this.imageUrl,
      stockQuantity: stockQuantity ?? this.stockQuantity,
    );
  }
}
