import 'package:dio/dio.dart';
import '../security/secure_storage_service.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'interceptors/auth_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  Dio get dio => _dio;

  ApiClient._internal() {
    final baseOptions = BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
      },
      responseType: ResponseType.json,
    );

    _dio = Dio(baseOptions);

    final storage = SecureStorageService();
    _dio.interceptors.add(AuthInterceptor(storage, _dio));
  }

  void _syncBaseUrl() {
    if (_dio.options.baseUrl != ApiEndpoints.baseUrl) {
      _dio.options.baseUrl = ApiEndpoints.baseUrl;
    }
  }

  Future<Response<dynamic>> _executeWithRetry(
    Future<Response<dynamic>> Function() request,
  ) async {
    _syncBaseUrl();
    try {
      return await request();
    } on DioException catch (e) {
      final isConnectionIssue = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          (e.error != null && e.error.toString().toLowerCase().contains('socketexception'));

      if (isConnectionIssue) {
        // Fast parallel re-scan to discover active server endpoint
        await ApiEndpoints.initialize(forceRecheck: true);
        _syncBaseUrl();
        // Retry request once with the newly discovered endpoint
        try {
          return await request();
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _executeWithRetry(
        () => _dio.get(
          path,
          queryParameters: queryParameters,
          options: options,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _executeWithRetry(
        () => _dio.post(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _executeWithRetry(
        () => _dio.patch(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _executeWithRetry(
        () => _dio.put(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _executeWithRetry(
        () => _dio.delete(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }
}
