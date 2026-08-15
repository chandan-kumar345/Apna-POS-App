class BusinessModel {
  final String id;
  final String ownerId;
  final BusinessProfile profile;
  final BusinessConfig business;
  final BusinessAddress address;
  final BusinessOrderSettings orderSettings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BusinessModel({
    required this.id,
    required this.ownerId,
    required this.profile,
    required this.business,
    required this.address,
    required this.orderSettings,
    this.createdAt,
    this.updatedAt,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] ?? json['_id'] ?? '',
      ownerId: json['ownerId'] ?? '',
      profile: BusinessProfile.fromJson(json['profile'] ?? {}),
      business: BusinessConfig.fromJson(json['business'] ?? {}),
      address: BusinessAddress.fromJson(json['address'] ?? {}),
      orderSettings: BusinessOrderSettings.fromJson(json['orderSettings'] ?? {}),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'profile': profile.toJson(),
        'business': business.toJson(),
        'address': address.toJson(),
        'orderSettings': orderSettings.toJson(),
      };
}

class BusinessProfile {
  final String profileImage;
  final String name;
  final String phone;
  final String companyName;
  final String website;
  final String referralCode;

  BusinessProfile({
    this.profileImage = '',
    this.name = '',
    this.phone = '',
    this.companyName = '',
    this.website = '',
    this.referralCode = '',
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      profileImage: json['profileImage']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      referralCode: json['referralCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'profileImage': profileImage,
        'name': name,
        'phone': phone,
        'companyName': companyName,
        'website': website,
        'referralCode': referralCode,
      };
}

class BusinessConfig {
  final String country;
  final String currency;
  final String timezone;
  final String businessType;

  BusinessConfig({
    this.country = 'IN',
    this.currency = 'INR',
    this.timezone = 'Asia/Kolkata',
    this.businessType = 'Restaurant',
  });

  factory BusinessConfig.fromJson(Map<String, dynamic> json) {
    return BusinessConfig(
      country: json['country']?.toString() ?? 'IN',
      currency: json['currency']?.toString() ?? 'INR',
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
      businessType: json['businessType']?.toString() ?? 'Restaurant',
    );
  }

  Map<String, dynamic> toJson() => {
        'country': country,
        'currency': currency,
        'timezone': timezone,
        'businessType': businessType,
      };
}

class BusinessAddress {
  final String addressLine;
  final String building;
  final String landmark;
  final String placeType;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final double latitude;
  final double longitude;

  BusinessAddress({
    this.addressLine = '',
    this.building = '',
    this.landmark = '',
    this.placeType = 'work',
    this.city = '',
    this.state = '',
    this.country = 'IN',
    this.postalCode = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory BusinessAddress.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lng = 0.0;
    final loc = json['location'] as Map<String, dynamic>?;
    if (loc != null && loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
      lng = ((loc['coordinates'] as List)[0] as num).toDouble();
      lat = ((loc['coordinates'] as List)[1] as num).toDouble();
    } else {
      lat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (json['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    return BusinessAddress(
      addressLine: json['addressLine']?.toString() ?? json['address']?.toString() ?? '',
      building: json['building']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      placeType: json['placeType']?.toString() ?? 'work',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? 'IN',
      postalCode: json['postalCode']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toJson() => {
        'addressLine': addressLine,
        'building': building,
        'landmark': landmark,
        'placeType': placeType,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class BusinessOrderSettings {
  final Map<String, bool> services;
  final String taxType;
  final String gstNumber;
  final double? taxPercentage;
  final String restaurantType;
  final Map<String, bool> paymentMethods;
  final String upiId;
  final int tableCount;

  BusinessOrderSettings({
    this.services = const {'dineIn': true, 'takeaway': false, 'delivery': false},
    this.taxType = 'gst',
    this.gstNumber = '',
    this.taxPercentage = 5.0,
    this.restaurantType = 'both',
    this.paymentMethods = const {'cash': true, 'upi': true, 'card': false},
    this.upiId = 'apnapos@upi',
    this.tableCount = 12,
  });

  factory BusinessOrderSettings.fromJson(Map<String, dynamic> json) {
    final srv = json['services'] as Map<String, dynamic>?;
    final tax = json['tax'] as Map<String, dynamic>?;
    final pm = json['paymentMethods'] as Map<String, dynamic>?;

    return BusinessOrderSettings(
      services: srv != null
          ? srv.map((k, v) => MapEntry(k, v == true))
          : const {'dineIn': true, 'takeaway': false, 'delivery': false},
      taxType: tax?['type']?.toString() ?? 'gst',
      gstNumber: tax?['gstNumber']?.toString() ?? '',
      taxPercentage: (tax?['percentage'] as num?)?.toDouble() ?? 5.0,
      restaurantType: json['restaurantType']?.toString() ?? 'both',
      paymentMethods: pm != null
          ? pm.map((k, v) => MapEntry(k, v == true))
          : const {'cash': true, 'upi': true, 'card': false},
      upiId: json['upiId']?.toString() ?? 'apnapos@upi',
      tableCount: (json['tableCount'] as num?)?.toInt() ?? 12,
    );
  }

  Map<String, dynamic> toJson() => {
        'services': services,
        'tax': {
          'type': taxType,
          'gstNumber': gstNumber,
          'percentage': taxPercentage,
        },
        'restaurantType': restaurantType,
        'paymentMethods': paymentMethods,
        'upiId': upiId,
        'tableCount': tableCount,
      };
}
