import 'package:dio/dio.dart';
import '../../security/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final ISecureStorageService _storageService;
  final Dio _dio;
  bool _isRefreshing = false;
  final List<Map<String, dynamic>> _failedRequestsQueue = [];

  AuthInterceptor(this._storageService, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _storageService.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    final deviceId = await _storageService.getDeviceId();
    if (deviceId != null) {
      options.headers['X-Device-ID'] = deviceId;
    }

    options.headers['X-Request-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
    
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/')) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          final newAccessToken = await _performTokenRefresh();
          _isRefreshing = false;

          if (newAccessToken != null) {
            for (var request in _failedRequestsQueue) {
              final options = request['options'] as RequestOptions;
              final h = request['handler'] as ErrorInterceptorHandler;
              options.headers['Authorization'] = 'Bearer $newAccessToken';
              
              final response = await _dio.fetch(options);
              h.resolve(response);
            }
            _failedRequestsQueue.clear();

            err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            final response = await _dio.fetch(err.requestOptions);
            return handler.resolve(response);
          }
        } catch (e) {
          _isRefreshing = false;
          _failedRequestsQueue.clear();
          await _storageService.clearAll();
        }
      } else {
        _failedRequestsQueue.add({'options': err.requestOptions, 'handler': handler});
        return;
      }
    }
    return handler.next(err);
  }

  Future<String?> _performTokenRefresh() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null) return null;

    final response = await _dio.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data['data'] ?? response.data;
      final newAccessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newAccessToken != null) {
        await _storageService.saveAccessToken(newAccessToken);
      }
      if (newRefreshToken != null) {
        await _storageService.saveRefreshToken(newRefreshToken);
      }

      return newAccessToken;
    }
    return null;
  }
}

