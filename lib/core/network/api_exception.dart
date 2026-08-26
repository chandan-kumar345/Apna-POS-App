import 'dart:convert';
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final String code;
  final int? statusCode;
  final Map<String, dynamic>? fields;

  ApiException({
    required this.message,
    this.code = 'API_ERROR',
    this.statusCode,
    this.fields,
  });

  factory ApiException.fromDioException(DioException error) {
    dynamic rawData = error.response?.data;
    if (rawData is String && rawData.trim().startsWith('{')) {
      try {
        rawData = jsonDecode(rawData);
      } catch (_) {}
    }

    if (rawData != null && rawData is Map) {
      final data = Map<String, dynamic>.from(rawData);
      final errObj = data['error'] as Map<String, dynamic>?;
      if (errObj != null) {
        String msg = errObj['message']?.toString() ?? 'An error occurred';
        final fields = errObj['fields'] as Map<String, dynamic>?;
        if (fields != null && fields.isNotEmpty) {
          final fieldMessages = fields.values
              .where((v) => v != null && v.toString().trim().isNotEmpty)
              .map((v) => v.toString().trim())
              .join('\n');
          if (fieldMessages.isNotEmpty) {
            msg = fieldMessages;
          }
        }
        return ApiException(
          message: msg,
          code: errObj['code']?.toString() ?? 'API_ERROR',
          statusCode: error.response?.statusCode,
          fields: fields,
        );
      }
      if (data['message'] != null) {
        return ApiException(
          message: data['message'].toString(),
          code: 'API_ERROR',
          statusCode: error.response?.statusCode,
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Unable to connect to server. Please check your internet connection and try again.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Cannot reach the server. Please verify your network connection and try again.',
          code: 'CONNECTION_ERROR',
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request was cancelled',
          code: 'REQUEST_CANCELLED',
        );
      default:
        return ApiException(
          message: error.message ?? 'An unexpected network error occurred. Please try again.',
          code: 'UNKNOWN_NETWORK_ERROR',
          statusCode: error.response?.statusCode,
        );
    }
  }

  @override
  String toString() => message;
}
