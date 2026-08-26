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
    final path = err.requestOptions.path;
    final isAuthNonRefreshable = path.endsWith('/auth/login') ||
        path.endsWith('/auth/register') ||
        path.endsWith('/auth/refresh') ||
        path.endsWith('/auth/reset-password');

    if (err.response?.statusCode == 401 && !isAuthNonRefreshable) {
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
          // Only clear if refreshToken is explicitly rejected
          if (e is DioException && e.response?.statusCode == 401) {
            await _storageService.clearAll();
          }
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
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final refreshUrl = _dio.options.baseUrl.endsWith('/api/v1')
        ? '${_dio.options.baseUrl}/auth/refresh'
        : '${_dio.options.baseUrl}/api/v1/auth/refresh';

    final response = await _dio.post(
      refreshUrl,
      data: {
        'refreshToken': refreshToken,
      },
      options: Options(
        headers: {
          'Authorization': '', // Avoid sending expired access token
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data['data'] ?? response.data;
      final newAccessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await _storageService.saveAccessToken(newAccessToken);
      }
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storageService.saveRefreshToken(newRefreshToken);
      }

      return newAccessToken;
    }
    return null;
  }
}

