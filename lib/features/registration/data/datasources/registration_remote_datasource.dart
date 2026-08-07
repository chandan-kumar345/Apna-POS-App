import 'package:dio/dio.dart';
import '../models/registration_request_model.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/services/email_service.dart';

abstract class IRegistrationRemoteDataSource {
  Future<Map<String, dynamic>> registerFullUser(RegistrationRequestModel model);
  Future<bool> verifyOtp(String identifier, String code, String purpose);
  Future<bool> resendOtp(String identifier, String channel);
}

class RegistrationRemoteDataSource implements IRegistrationRemoteDataSource {
  final Dio _dio;
  final DatabaseService _dbService;
  final EmailService _emailService;

  RegistrationRemoteDataSource(this._dio)
      : _dbService = DatabaseService(),
        _emailService = EmailService();

  @override
  Future<Map<String, dynamic>> registerFullUser(RegistrationRequestModel model) async {
    // Send Email OTP from sooftcode@gmail.com to user's registered email
    await _emailService.sendOtpEmail(model.entity.email);

    try {
      final formData = await model.toFormData();
      
      // Attempt API network registration
      final response = await _dio.post(
        '/api/v1/auth/register-full',
        data: formData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      // Fallback & local SQLite integration for seamless offline / demo mode
      final entity = model.entity;
      await _dbService.registerUser(
        name: entity.fullName,
        email: entity.email,
        password: entity.password,
        pin: '1234',
        phone: entity.phone,
      );
      
      await _dbService.updateUserProfile(
        name: entity.fullName,
        phone: entity.phone,
        jobTitle: 'Owner / Manager',
        companyName: entity.businessName ?? 'Apna POS Store',
        referralCode: entity.referralCode,
        profilePhotoPath: entity.profilePhotoPath,
      );
    }

    return {
      'status': 'success',
      'message': 'Registration completed. Verification OTP sent from sooftcode@gmail.com.',
      'email': model.entity.email,
    };
  }

  @override
  Future<bool> verifyOtp(String identifier, String code, String purpose) async {
    try {
      final response = await _dio.post('/api/v1/auth/verify-otp', data: {
        'identifier': identifier,
        'code': code,
        'purpose': purpose,
      });
      if (response.statusCode == 200) return true;
    } catch (_) {}
    
    // Verify against EmailService active OTPs or local demo fallback
    return _emailService.verifyOtp(identifier, code);
  }

  @override
  Future<bool> resendOtp(String identifier, String channel) async {
    await _emailService.sendOtpEmail(identifier);
    try {
      final response = await _dio.post('/api/v1/auth/resend-otp', data: {
        'identifier': identifier,
        'channel': channel,
      });
      return response.statusCode == 200;
    } catch (_) {
      return true;
    }
  }
}
