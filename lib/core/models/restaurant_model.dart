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

  // New Business Settings fields
  final List<String> services; // e.g., ['Dine In', 'Takeaway', 'Delivery']
  final String billingType; // 'GST' or 'Non-GST'
  final String gstNumber; // e.g., '07AAAAA0000A1Z5'
  final String restaurantType; // 'Veg', 'Non-Veg', 'Both'
  final String openingTime; // '09:00 AM'
  final String closingTime; // '11:00 PM'
  final List<String> kitchenSections; // ['Main Kitchen', 'Beverages Bar']
  final String upiId; // Merchant UPI VPA ID e.g., 'merchant@upi' or '9876543210@paytm'

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
    this.services = const ['Dine In'],
    this.billingType = 'GST',
    this.gstNumber = '',
    this.restaurantType = 'Both',
    this.openingTime = '09:00 AM',
    this.closingTime = '11:00 PM',
    this.kitchenSections = const ['Main Kitchen', 'Beverages Bar'],
    this.upiId = 'apnapos@upi',
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
        'services': services,
        'billingType': billingType,
        'gstNumber': gstNumber,
        'restaurantType': restaurantType,
        'openingTime': openingTime,
        'closingTime': closingTime,
        'kitchenSections': kitchenSections,
        'upiId': upiId,
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
        services: (json['services'] as List?)?.map((e) => e.toString()).toList() ?? const ['Dine In'],
        billingType: json['billingType'] ?? 'GST',
        gstNumber: json['gstNumber'] ?? '',
        restaurantType: json['restaurantType'] ?? 'Both',
        openingTime: json['openingTime'] ?? '09:00 AM',
        closingTime: json['closingTime'] ?? '11:00 PM',
        kitchenSections:
            (json['kitchenSections'] as List?)?.map((e) => e.toString()).toList() ?? const ['Main Kitchen', 'Beverages Bar'],
        upiId: json['upiId'] ?? 'apnapos@upi',
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
    List<String>? services,
    String? billingType,
    String? gstNumber,
    String? restaurantType,
    String? openingTime,
    String? closingTime,
    List<String>? kitchenSections,
    String? upiId,
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
      services: services ?? this.services,
      billingType: billingType ?? this.billingType,
      gstNumber: gstNumber ?? this.gstNumber,
      restaurantType: restaurantType ?? this.restaurantType,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      kitchenSections: kitchenSections ?? this.kitchenSections,
      upiId: upiId ?? this.upiId,
    );
  }
}
