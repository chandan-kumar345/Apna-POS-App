class UserRegistrationEntity {
  final String username;
  final String email;
  final String phone;
  final String password;
  final String fullName;
  final String? profilePhotoPath;
  final String? dateOfBirth;
  final String? gender;
  final String streetAddress;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final String preferredLanguage;
  final String currency;
  final String timeZone;
  final String? businessName;
  final String? businessType;
  final String? gstNumber;
  final String? referralCode;
  final bool termsAccepted;
  final bool privacyPolicyAccepted;
  final bool marketingConsent;
  final String appVersion;
  final String deviceId;
  final String deviceModel;
  final String operatingSystem;
  final String? pushToken;
  final String registrationSource;

  UserRegistrationEntity({
    required this.username,
    required this.email,
    required this.phone,
    required this.password,
    required this.fullName,
    this.profilePhotoPath,
    this.dateOfBirth,
    this.gender,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
    this.latitude,
    this.longitude,
    required this.preferredLanguage,
    required this.currency,
    required this.timeZone,
    this.businessName,
    this.businessType,
    this.gstNumber,
    this.referralCode,
    required this.termsAccepted,
    required this.privacyPolicyAccepted,
    required this.marketingConsent,
    required this.appVersion,
    required this.deviceId,
    required this.deviceModel,
    required this.operatingSystem,
    this.pushToken,
    required this.registrationSource,
  });
}
