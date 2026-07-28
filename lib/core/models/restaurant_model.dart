class RestaurantModel {
  final String id;
  final String name;
  final String tagline;
  final String phone;
  final String address;
  final String cuisineType;
  final String currencySymbol;
  final double taxRate; // e.g., 5.0 for 5% GST
  final double serviceCharge;
  final int tableCount;
  final bool isOnboarded;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.phone,
    required this.address,
    required this.cuisineType,
    this.currencySymbol = '₹',
    this.taxRate = 5.0,
    this.serviceCharge = 0.0,
    this.tableCount = 12,
    this.isOnboarded = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tagline': tagline,
        'phone': phone,
        'address': address,
        'cuisineType': cuisineType,
        'currencySymbol': currencySymbol,
        'taxRate': taxRate,
        'serviceCharge': serviceCharge,
        'tableCount': tableCount,
        'isOnboarded': isOnboarded,
      };

  factory RestaurantModel.fromJson(Map<String, dynamic> json) => RestaurantModel(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Apna Restaurant',
        tagline: json['tagline'] ?? 'Taste the Perfection',
        phone: json['phone'] ?? '+91 98765 43210',
        address: json['address'] ?? 'Connaught Place, New Delhi',
        cuisineType: json['cuisineType'] ?? 'Indian & Multi-Cuisine',
        currencySymbol: json['currencySymbol'] ?? '₹',
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 5.0,
        serviceCharge: (json['serviceCharge'] as num?)?.toDouble() ?? 0.0,
        tableCount: json['tableCount'] ?? 12,
        isOnboarded: json['isOnboarded'] ?? false,
      );

  RestaurantModel copyWith({
    String? name,
    String? tagline,
    String? phone,
    String? address,
    String? cuisineType,
    String? currencySymbol,
    double? taxRate,
    double? serviceCharge,
    int? tableCount,
    bool? isOnboarded,
  }) {
    return RestaurantModel(
      id: id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      cuisineType: cuisineType ?? this.cuisineType,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxRate: taxRate ?? this.taxRate,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tableCount: tableCount ?? this.tableCount,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}
