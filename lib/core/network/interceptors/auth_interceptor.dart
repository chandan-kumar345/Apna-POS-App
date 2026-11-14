import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../security/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final ISecureStorageService _storageService;
  final Dio _dio;
  final Dio? _refreshClient;
  Future<String?>? _refreshInFlight;
  static const _retriedKey = 'apna_auth_retried';

  AuthInterceptor(this._storageService, this._dio, {Dio? refreshClient})
    // Public injection argument; keep the backing field private.
    // ignore: prefer_initializing_formals
    : _refreshClient = refreshClient;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;
    final isAuthEndpoint =
        path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/refresh-token') ||
        path.contains('/auth/reset-password');

    if (!isAuthEndpoint && !options.headers.containsKey('Authorization')) {
      var accessToken = await _storageService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          accessToken =
              prefs.getString('SEC_KEY_AT_V1') ??
              prefs.getString('access_token') ??
              prefs.getString('token');
          if (accessToken != null && accessToken.isNotEmpty) {
            await _storageService.saveAccessToken(accessToken);
          }
        } catch (_) {}
      }
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    final deviceId = await _storageService.getDeviceId();
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      options.headers['X-Device-ID'] = deviceId.trim();
    }

    final businessId = await _storageService.getBusinessId();
    if (businessId != null &&
        businessId.trim().isNotEmpty &&
        businessId.trim() != 'rest_001' &&
        !businessId.trim().startsWith('rest_')) {
      options.headers['X-Business-ID'] = businessId.trim();
    }

    options.headers['X-Request-Timestamp'] = DateTime.now()
        .millisecondsSinceEpoch
        .toString();

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final path = err.requestOptions.path;
    final isAuthNonRefreshable =
        path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/refresh-token') ||
        path.contains('/auth/reset-password');

    if (err.response?.statusCode != 401 ||
        isAuthNonRefreshable ||
        err.requestOptions.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    String? accessToken;
    try {
      final current = await _storageService.getAccessToken();
      final attempted = err.requestOptions.headers['Authorization'];
      // A late 401 can belong to the token replaced by another request. Reuse
      // that replacement instead of rotating the refresh token a second time.
      accessToken =
          current != null &&
              current.isNotEmpty &&
              attempted != 'Bearer $current'
          ? current
          : await (_refreshInFlight ??= _refreshOnce());
    } catch (_) {
      return handler.next(err);
    }

    if (accessToken == null || accessToken.isEmpty) return handler.next(err);
    err.requestOptions.extra[_retriedKey] = true;
    err.requestOptions.headers['Authorization'] = 'Bearer $accessToken';
    try {
      return handler.resolve(await _dio.fetch(err.requestOptions));
    } on DioException catch (retryError) {
      // A resource's retry can be denied independently of token validity. Never
      // treat that response as a rejected refresh or recursively refresh again.
      return handler.next(retryError);
    } catch (error) {
      return handler.next(
        DioException(requestOptions: err.requestOptions, error: error),
      );
    }
  }

  Future<String?> _refreshOnce() async {
    try {
      return await _performTokenRefresh();
    } on DioException catch (error) {
      // Clear credentials only when the refresh endpoint explicitly rejects
      // them. Offline failures, malformed responses, and resource 401s retain
      // the saved session for the next retry/reopen.
      if (error.response?.statusCode == 401) await _storageService.clearAll();
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _performTokenRefresh() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final refreshDio =
        _refreshClient ??
        Dio(
          BaseOptions(
            baseUrl: _dio.options.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Bypass-Tunnel-Reminder': 'true',
            },
          ),
        );

    final refreshPath = _dio.options.baseUrl.endsWith('/api/v1')
        ? '/auth/refresh'
        : '/api/v1/auth/refresh';

    try {
      final response = await refreshDio.post(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = data['refreshToken'] as String?;

        // Persist the rotated refresh token first. If the process closes while
        // saving the access token, the next launch can still obtain a new pair.
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await _storageService.saveRefreshToken(newRefreshToken);
        }
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _storageService.saveAccessToken(newAccessToken);
        }

        return newAccessToken;
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }
}
