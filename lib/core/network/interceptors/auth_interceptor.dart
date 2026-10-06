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
    final path = options.path;
    final isAuthEndpoint = path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/refresh-token') ||
        path.contains('/auth/reset-password');

    if (!isAuthEndpoint && !options.headers.containsKey('Authorization')) {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    final deviceId = await _storageService.getDeviceId();
    if (deviceId != null) {
      options.headers['X-Device-ID'] = deviceId;
    }

    final businessId = await _storageService.getBusinessId();
    if (businessId != null && businessId.trim().isNotEmpty) {
      options.headers['X-Business-ID'] = businessId.trim();
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
    final isAuthNonRefreshable = path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/refresh-token') ||
        path.contains('/auth/reset-password');

    if (err.response?.statusCode == 401 && !isAuthNonRefreshable) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          final newAccessToken = await _performTokenRefresh();
          _isRefreshing = false;

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            // Replay queued requests with updated token
            final queueCopy = List<Map<String, dynamic>>.from(_failedRequestsQueue);
            _failedRequestsQueue.clear();

            for (var request in queueCopy) {
              final options = request['options'] as RequestOptions;
              final h = request['handler'] as ErrorInterceptorHandler;
              options.headers['Authorization'] = 'Bearer $newAccessToken';
              try {
                final response = await _dio.fetch(options);
                h.resolve(response);
              } catch (retryErr) {
                if (retryErr is DioException) {
                  h.reject(retryErr);
                } else {
                  h.reject(DioException(requestOptions: options, error: retryErr));
                }
              }
            }

            // Retry original failed request
            err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            final response = await _dio.fetch(err.requestOptions);
            return handler.resolve(response);
          } else {
            _rejectQueue(err);
            await _storageService.clearAll();
          }
        } catch (e) {
          _isRefreshing = false;
          _rejectQueue(err);
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

  void _rejectQueue(DioException err) {
    final queueCopy = List<Map<String, dynamic>>.from(_failedRequestsQueue);
    _failedRequestsQueue.clear();
    for (var request in queueCopy) {
      final h = request['handler'] as ErrorInterceptorHandler;
      final options = request['options'] as RequestOptions;
      h.reject(DioException(
        requestOptions: options,
        error: err.error,
        response: err.response,
        type: err.type,
      ));
    }
  }

  Future<String?> _performTokenRefresh() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final refreshDio = Dio(BaseOptions(
      baseUrl: _dio.options.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
      },
    ));

    final refreshPath = _dio.options.baseUrl.endsWith('/api/v1')
        ? '/auth/refresh'
        : '/api/v1/auth/refresh';

    try {
      final response = await refreshDio.post(
        refreshPath,
        data: {
          'refreshToken': refreshToken,
        },
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
    } catch (_) {
      rethrow;
    }
    return null;
  }
}

