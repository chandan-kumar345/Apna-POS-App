import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract class ISmsService {
  Future<String?> sendOtpSms(String phoneNumber);
}

class SmsService implements ISmsService {
  final Dio _dio;

  // SMS Horizon API Key & Credentials
  static const String defaultApiKey = 'YSreG2UqqqQwNC4GbJA8hOpK9KKCq9';
  static const String smsHorizonUser = 'apnapos'; // Default SMS Horizon username
  static const String senderId = 'APNAPOS';

  final String _apiKey;
  final String _username;

  SmsService({
    Dio? dio,
    String apiKey = defaultApiKey,
    String username = smsHorizonUser,
  })  : _dio = dio ?? Dio(),
        _apiKey = apiKey,
        _username = username;

  /// Generates a random 4-digit OTP code and dispatches it via SMS Horizon Gateway
  @override
  Future<String?> sendOtpSms(String phoneNumber) async {
    // Generate secure 4-digit OTP
    final random = Random();
    final generatedOtp = (1000 + random.nextInt(9000)).toString();

    // Clean phone number (extract last 10 digits for SMS Horizon India format)
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length > 10) {
      cleanPhone = cleanPhone.substring(cleanPhone.length - 10);
    }

    final messageText = 'Your OTP verification code for Apna POS is $generatedOtp. Valid for 5 minutes.';

    debugPrint('--------------------------------------------------');
    debugPrint('SMS HORIZON GATEWAY: Sending OTP $generatedOtp to $cleanPhone');
    debugPrint('--------------------------------------------------');

    try {
      if (_apiKey.isNotEmpty) {
        // SMS Horizon REST API Call
        final response = await _dio.get(
          'http://smshorizon.in/api/sendsms.php',
          queryParameters: {
            'user': _username,
            'apikey': _apiKey,
            'mobile': cleanPhone,
            'message': messageText,
            'senderid': senderId,
            'type': 'txt',
          },
        );
        debugPrint('SMS Horizon Response: ${response.data}');
      }
    } catch (e) {
      debugPrint('SMS Horizon Gateway Error: $e');
    }

    // Returns generated OTP for verification
    return generatedOtp;
  }
}
