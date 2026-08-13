import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Authentication API Service interfacing with Node.js /api/auth endpoints.
class AuthApi {
  final ApiClient _client = ApiClient();

  /// Register user account via backend API
  Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    String? phone,
    required String password,
    String? businessName,
  }) async {
    final response = await _client.post(
      '/auth/register',
      body: {
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
        if (businessName != null) 'businessName': businessName,
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Registration failed via API.');
    }
  }

  /// Login using email/phone + password via backend API
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Invalid login credentials.');
    }
  }

  /// Request OTP for phone authentication
  Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String purpose = 'login',
  }) async {
    final response = await _client.post(
      '/auth/send-otp',
      body: {
        'phone': phone,
        'purpose': purpose,
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to send OTP code.');
    }
  }

  /// Verify OTP code and log in / register
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? name,
  }) async {
    final response = await _client.post(
      '/auth/verify-otp',
      body: {
        'phone': phone,
        'otp': otp,
        if (name != null) 'name': name,
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'OTP verification failed.');
    }
  }
}
