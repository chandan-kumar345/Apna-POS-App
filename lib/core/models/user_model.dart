class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // Owner, Manager, Cashier, Waiter
  final String pin;
  final String restaurantId;
  final String? phone;
  final String? jobTitle;
  final String? companyName;
  final String? website;
  final String? referralCode;
  final String? profilePhotoPath;
  final Map<String, bool>? communicationPreferences;
  final bool onboardingCompleted;
  final int onboardingStep;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.pin,
    required this.restaurantId,
    this.phone,
    this.jobTitle,
    this.companyName,
    this.website,
    this.referralCode,
    this.profilePhotoPath,
    this.communicationPreferences,
    this.onboardingCompleted = false,
    this.onboardingStep = 0,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? pin,
    String? restaurantId,
    String? phone,
    String? jobTitle,
    String? companyName,
    String? website,
    String? referralCode,
    String? profilePhotoPath,
    Map<String, bool>? communicationPreferences,
    bool? onboardingCompleted,
    int? onboardingStep,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      restaurantId: restaurantId ?? this.restaurantId,
      phone: phone ?? this.phone,
      jobTitle: jobTitle ?? this.jobTitle,
      companyName: companyName ?? this.companyName,
      website: website ?? this.website,
      referralCode: referralCode ?? this.referralCode,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      communicationPreferences:
          communicationPreferences ?? this.communicationPreferences,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingStep: onboardingStep ?? this.onboardingStep,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'pin': pin,
        'restaurantId': restaurantId,
        'phone': phone,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'website': website,
        'referralCode': referralCode,
        'profilePhotoPath': profilePhotoPath,
        'communicationPreferences': communicationPreferences,
        'onboardingCompleted': onboardingCompleted,
        'onboardingStep': onboardingStep,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? json['_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'Owner',
        pin: json['pin'] ?? '1234',
        restaurantId: json['restaurantId'] ?? '',
        phone: json['phone'],
        jobTitle: json['jobTitle'],
        companyName: json['companyName'],
        website: json['website'],
        referralCode: json['referralCode'],
        profilePhotoPath: json['profilePhotoPath'],
        communicationPreferences: json['communicationPreferences'] != null
            ? Map<String, bool>.from(json['communicationPreferences'])
            : null,
        onboardingCompleted: json['onboardingCompleted'] == true,
        onboardingStep: (json['onboardingStep'] as num?)?.toInt() ?? 0,
      );
}
