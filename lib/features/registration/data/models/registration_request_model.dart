import 'package:dio/dio.dart';
import '../../domain/entities/user_registration_entity.dart';

class RegistrationRequestModel {
  final UserRegistrationEntity entity;

  RegistrationRequestModel(this.entity);

  Future<FormData> toFormData() async {
    final Map<String, dynamic> fields = {
      'username': entity.username,
      'email': entity.email,
      'phone': entity.phone,
      'password': entity.password,
      'fullName': entity.fullName,
      'dateOfBirth': entity.dateOfBirth,
      'gender': entity.gender,
      'streetAddress': entity.streetAddress,
      'city': entity.city,
      'state': entity.state,
      'country': entity.country,
      'pincode': entity.pincode,
      'latitude': entity.latitude,
      'longitude': entity.longitude,
      'preferredLanguage': entity.preferredLanguage,
      'currency': entity.currency,
      'timeZone': entity.timeZone,
      'businessName': entity.businessName,
      'businessType': entity.businessType,
      'gstNumber': entity.gstNumber,
      'referralCode': entity.referralCode,
      'termsAccepted': entity.termsAccepted,
      'privacyPolicyAccepted': entity.privacyPolicyAccepted,
      'marketingConsent': entity.marketingConsent,
      'appVersion': entity.appVersion,
      'deviceId': entity.deviceId,
      'deviceModel': entity.deviceModel,
      'operatingSystem': entity.operatingSystem,
      'pushToken': entity.pushToken,
      'registrationSource': entity.registrationSource,
    };

    final formData = FormData.fromMap(fields);

    if (entity.profilePhotoPath != null && entity.profilePhotoPath!.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'profilePhoto',
          await MultipartFile.fromFile(
            entity.profilePhotoPath!,
            filename: entity.profilePhotoPath!.split('/').last,
          ),
        ),
      );
    }

    return formData;
  }
}
