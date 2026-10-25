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
  final String posViewMode; // 'with_image' or 'without_image'
  final String managerPin; // Security / Manager PIN to clear running KOT carts & void orders (default: '1234')
  final bool enableChotuVoice; // Whether Chotu AI Voice assistant icon is enabled in POS

  // Delivery Settings fields
  final double deliveryBaseCharge; // Base charge for delivery (₹)
  final double deliveryChargePerKm; // Additional charge per kilometer (₹/km)
  final bool freeDeliveryEnabled; // Whether free delivery is enabled
  final double freeDeliveryMinOrder; // Minimum order value required for free delivery (₹)
  final double maxDeliveryDistanceKm; // Maximum serviceable delivery radius (km)

  final String? logoUrl;
  final bool isSubscribed;
  final String companyName;
  final String slug;
  final bool isStorefrontOnline;
  final int storefrontThemeColor;

  static String slugify(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return 'store';
    final replaced = clean.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return replaced.isNotEmpty ? replaced : 'store';
  }

  String get storefrontSlug {
    if (slug.trim().isNotEmpty) return slug.trim();
    if (companyName.trim().isNotEmpty) return slugify(companyName);
    if (name.trim().isNotEmpty) return slugify(name);
    return id.isNotEmpty ? 'store-$id' : 'apna-store';
  }

  String get storefrontUrl => 'https://apnaposs.vercel.app/$storefrontSlug';

  bool get showItemImages => posViewMode != 'without_image';

  RestaurantModel({
    required this.id,
    required this.name,
    this.companyName = '',
    this.slug = '',
    this.isStorefrontOnline = true,
    this.storefrontThemeColor = 0xFFE65100,
    required this.tagline,
    required this.phone,
    required this.address,
    required this.cuisineType,
    this.currencySymbol = '₹',
    this.taxRate = 5.0,
    this.serviceCharge = 0.0,
    this.tableCount = 12,
    this.isOnboarded = false,
    this.isSubscribed = false,
    this.services = const ['Dine In'],
    this.billingType = 'GST',
    this.gstNumber = '',
    this.restaurantType = 'Both',
    this.openingTime = '09:00 AM',
    this.closingTime = '11:00 PM',
    this.kitchenSections = const ['Main Kitchen', 'Beverages Bar'],
    this.upiId = 'apnapos@upi',
    this.posViewMode = 'with_image',
    this.managerPin = '1234',
    this.enableChotuVoice = true,
    this.deliveryBaseCharge = 0.0,
    this.deliveryChargePerKm = 0.0,
    this.freeDeliveryEnabled = false,
    this.freeDeliveryMinOrder = 0.0,
    this.maxDeliveryDistanceKm = 10.0,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'companyName': companyName,
        'slug': storefrontSlug,
        'isStorefrontOnline': isStorefrontOnline,
        'storefrontThemeColor': storefrontThemeColor,
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
        'posViewMode': posViewMode,
        'managerPin': managerPin,
        'enableChotuVoice': enableChotuVoice,
        'deliveryBaseCharge': deliveryBaseCharge,
        'deliveryChargePerKm': deliveryChargePerKm,
        'freeDeliveryEnabled': freeDeliveryEnabled,
        'freeDeliveryMinOrder': freeDeliveryMinOrder,
        'maxDeliveryDistanceKm': maxDeliveryDistanceKm,
        'deliverySettings': {
          'baseCharge': deliveryBaseCharge,
          'chargePerKm': deliveryChargePerKm,
          'freeDeliveryEnabled': freeDeliveryEnabled,
          'freeDeliveryMinOrder': freeDeliveryMinOrder,
          'maxDistanceKm': maxDeliveryDistanceKm,
        },
        'logoUrl': logoUrl,
        'isSubscribed': isSubscribed,
        'isSubscriptionActive': isSubscribed,
      };

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final ds = (json['deliverySettings'] is Map ? json['deliverySettings'] : null) ??
        (json['orderSettings'] is Map && json['orderSettings']['deliverySettings'] is Map
            ? json['orderSettings']['deliverySettings']
            : null);

    return RestaurantModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? json['businessId']?.toString() ?? '',
        name: json['name'] ?? (json['profile'] is Map ? json['profile']['name'] : null) ?? 'Apna Restaurant',
        companyName: json['companyName']?.toString() ??
            (json['profile'] is Map ? json['profile']['companyName']?.toString() : null) ??
            '',
        tagline: json['tagline'] ?? 'Taste the Perfection',
        phone: json['phone'] ?? '+91 98765 43210',
        address: json['address'] ?? 'Connaught Place, New Delhi',
        cuisineType: json['cuisineType'] ?? 'Indian & Multi-Cuisine',
        currencySymbol: json['currencySymbol'] ?? '₹',
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 5.0,
        serviceCharge: (json['serviceCharge'] as num?)?.toDouble() ?? 0.0,
        tableCount: json['tableCount'] ?? 12,
        isOnboarded: json['isOnboarded'] ?? false,
        isSubscribed: json['isSubscribed'] == true ||
            json['isSubscriptionActive'] == true ||
            json['isActive'] == true ||
            (json['subscription'] is Map &&
                (json['subscription']['isSubscriptionActive'] == true ||
                 json['subscription']['isActive'] == true ||
                 json['subscription']['isSubscribed'] == true ||
                 json['subscription']['status'] == 'active')) ||
            (json['premiumSubscription'] is Map &&
                (json['premiumSubscription']['isSubscriptionActive'] == true ||
                 json['premiumSubscription']['isActive'] == true ||
                 json['premiumSubscription']['isSubscribed'] == true ||
                 json['premiumSubscription']['status'] == 'active')),
        services: (json['services'] as List?)?.map((e) => e.toString()).toList() ?? const ['Dine In'],
        billingType: json['billingType'] ?? 'GST',
        gstNumber: json['gstNumber'] ?? '',
        restaurantType: json['restaurantType'] ?? 'Both',
        openingTime: json['openingTime'] ?? '09:00 AM',
        closingTime: json['closingTime'] ?? '11:00 PM',
        kitchenSections:
            (json['kitchenSections'] as List?)?.map((e) => e.toString()).toList() ?? const ['Main Kitchen', 'Beverages Bar'],
        upiId: json['upiId'] ?? 'apnapos@upi',
        posViewMode: json['posViewMode'] ?? (json['orderSettings'] is Map ? json['orderSettings']['posViewMode'] : null) ?? 'with_image',
        managerPin: json['managerPin']?.toString().trim().isNotEmpty == true
            ? json['managerPin'].toString().trim()
            : (json['securityPin']?.toString().trim().isNotEmpty == true
                ? json['securityPin'].toString().trim()
                : '1234'),
        enableChotuVoice: json['enableChotuVoice'] ?? (json['orderSettings'] is Map ? json['orderSettings']['enableChotuVoice'] : null) ?? true,
        deliveryBaseCharge: (json['deliveryBaseCharge'] as num?)?.toDouble() ??
            (ds != null && ds['baseCharge'] != null ? (ds['baseCharge'] as num?)?.toDouble() : null) ??
            0.0,
        deliveryChargePerKm: (json['deliveryChargePerKm'] as num?)?.toDouble() ??
            (ds != null && ds['chargePerKm'] != null ? (ds['chargePerKm'] as num?)?.toDouble() : null) ??
            0.0,
        freeDeliveryEnabled: json['freeDeliveryEnabled'] == true || (ds != null && ds['freeDeliveryEnabled'] == true),
        freeDeliveryMinOrder: (json['freeDeliveryMinOrder'] as num?)?.toDouble() ??
            (ds != null && ds['freeDeliveryMinOrder'] != null ? (ds['freeDeliveryMinOrder'] as num?)?.toDouble() : null) ??
            0.0,
        maxDeliveryDistanceKm: (json['maxDeliveryDistanceKm'] as num?)?.toDouble() ??
            (ds != null && ds['maxDistanceKm'] != null ? (ds['maxDistanceKm'] as num?)?.toDouble() : null) ??
            10.0,
        logoUrl: json['logoUrl']?.toString() ??
            json['logo']?.toString() ??
            json['profileImage']?.toString() ??
            json['profileLogo']?.toString() ??
            json['profilePhotoPath']?.toString() ??
            (json['profile'] is Map ? (json['profile']['profileImage'] ?? json['profile']['logoUrl'] ?? json['profile']['logo'])?.toString() : null),
        slug: json['slug']?.toString() ??
            (json['profile'] is Map ? json['profile']['slug']?.toString() : null) ??
            '',
        isStorefrontOnline: json['isStorefrontOnline'] is bool
            ? json['isStorefrontOnline'] as bool
            : (json['isOnline'] is bool ? json['isOnline'] as bool : true),
        storefrontThemeColor: (json['storefrontThemeColor'] as num?)?.toInt() ?? 0xFFE65100,
      );
  }

  String? get businessId => id.isNotEmpty ? id : null;

  RestaurantModel copyWith({
    String? id,
    String? name,
    String? companyName,
    String? slug,
    bool? isStorefrontOnline,
    int? storefrontThemeColor,
    String? tagline,
    String? phone,
    String? address,
    String? cuisineType,
    String? currencySymbol,
    double? taxRate,
    double? serviceCharge,
    int? tableCount,
    bool? isOnboarded,
    bool? isSubscribed,
    List<String>? services,
    String? billingType,
    String? gstNumber,
    String? restaurantType,
    String? openingTime,
    String? closingTime,
    List<String>? kitchenSections,
    String? upiId,
    String? posViewMode,
    String? managerPin,
    bool? enableChotuVoice,
    double? deliveryBaseCharge,
    double? deliveryChargePerKm,
    bool? freeDeliveryEnabled,
    double? freeDeliveryMinOrder,
    double? maxDeliveryDistanceKm,
    String? logoUrl,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      slug: slug ?? this.slug,
      isStorefrontOnline: isStorefrontOnline ?? this.isStorefrontOnline,
      storefrontThemeColor: storefrontThemeColor ?? this.storefrontThemeColor,
      tagline: tagline ?? this.tagline,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      cuisineType: cuisineType ?? this.cuisineType,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxRate: taxRate ?? this.taxRate,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tableCount: tableCount ?? this.tableCount,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      services: services ?? this.services,
      billingType: billingType ?? this.billingType,
      gstNumber: gstNumber ?? this.gstNumber,
      restaurantType: restaurantType ?? this.restaurantType,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      kitchenSections: kitchenSections ?? this.kitchenSections,
      upiId: upiId ?? this.upiId,
      posViewMode: posViewMode ?? this.posViewMode,
      managerPin: managerPin ?? this.managerPin,
      enableChotuVoice: enableChotuVoice ?? this.enableChotuVoice,
      deliveryBaseCharge: deliveryBaseCharge ?? this.deliveryBaseCharge,
      deliveryChargePerKm: deliveryChargePerKm ?? this.deliveryChargePerKm,
      freeDeliveryEnabled: freeDeliveryEnabled ?? this.freeDeliveryEnabled,
      freeDeliveryMinOrder: freeDeliveryMinOrder ?? this.freeDeliveryMinOrder,
      maxDeliveryDistanceKm: maxDeliveryDistanceKm ?? this.maxDeliveryDistanceKm,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
