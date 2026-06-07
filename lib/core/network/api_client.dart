import 'package:dio/dio.dart';
import '../config/environment_service.dart';
import '../constants/api_constants.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;

  /// Called when token refresh fails and the session cannot be recovered.
  /// Wire this to AuthProvider.logout() from AuthGate so the user is sent
  /// back to the login screen automatically.
  static void Function()? onUnauthorized;

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: EnvironmentService.instance.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.addAll([
      _AuthRefreshInterceptor(),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) {},
      ),
    ]);

  // ── Token management delegates to EnvironmentService ─────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) =>
      EnvironmentService.instance
          .saveTokens(accessToken: accessToken, refreshToken: refreshToken);

  Future<String?> get accessToken => EnvironmentService.instance.getAccessToken();
  Future<String?> get refreshToken => EnvironmentService.instance.getRefreshToken();
  Future<void> clearTokens() => EnvironmentService.instance.clearTokens();
  Future<bool> get hasTokens => EnvironmentService.instance.hasTokens;
}

/// Handles every outgoing request and intercepts 401 responses.
///
/// On 401:
///   1. Calls the refresh endpoint (handles both JSON-body and Set-Cookie tokens).
///   2. If refresh succeeds → retries the original request with the new token.
///   3. If refresh fails    → clears stored tokens and fires [ApiClient.onUnauthorized]
///      so the app navigates the user back to the login screen.
class _AuthRefreshInterceptor extends Interceptor {
  bool _isRefreshing = false;

  // Accesses ApiClient.instance.dio at call-time (not init-time) — no circular ref.
  Dio get _dio => ApiClient.instance.dio;

  // ── Request ───────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final env = EnvironmentService.instance;

    options.baseUrl = env.baseUrl;

    final token = await env.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Cookie'] = 'access_token_cookie=$token';
      options.headers['Authorization'] = 'Bearer $token';
    }

    // /org/current must NOT receive x-org-id — it would filter to 1 org only.
    // Also skip if the caller explicitly set x-org-id to null as an override.
    final callerSuppressed = options.headers.containsKey('x-org-id') &&
        options.headers['x-org-id'] == null;
    final pathSuppressed = options.path.contains('/auth/') ||
        options.path.contains('/org/current');

    if (!callerSuppressed && !pathSuppressed) {
      final orgId = await env.getOrgId();
      if (orgId != null && orgId.isNotEmpty) {
        options.headers['x-org-id'] = orgId;
      }
    } else {
      // Ensure null entry doesn't get sent as a literal header
      options.headers.remove('x-org-id');
    }

    handler.next(options);
  }

  // ── Error / 401 handling ──────────────────────────────────────────

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final isAuthPath = err.requestOptions.path.contains('/auth/');

    // Only auto-refresh on 401s outside the auth endpoints,
    // and prevent re-entrant refresh loops.
    if (is401 && !isAuthPath && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _doRefresh();
        if (refreshed) {
          // Inject the fresh token and replay the original request.
          final opts = err.requestOptions;
          final newToken = await EnvironmentService.instance.getAccessToken();
          if (newToken != null && newToken.isNotEmpty) {
            opts.headers['Cookie'] = 'access_token_cookie=$newToken';
            opts.headers['Authorization'] = 'Bearer $newToken';
          }
          final retryResponse = await _dio.fetch(opts);
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        // Fall through to session expiry handling.
      } finally {
        _isRefreshing = false;
      }

      // Refresh failed — clear session and notify the app.
      await EnvironmentService.instance.clearTokens();
      ApiClient.onUnauthorized?.call();
    }

    handler.next(err);
  }

  // ── Token refresh ─────────────────────────────────────────────────

  Future<bool> _doRefresh() async {
    final storedRefresh = await EnvironmentService.instance.getRefreshToken();
    if (storedRefresh == null || storedRefresh.isEmpty) return false;

    try {
      final response = await _dio.post(
        ApiConstants.refresh,
        options: Options(
          headers: {
            'Cookie': 'refresh_token_cookie=$storedRefresh',
            // Skip the auth interceptor re-entry for this call.
            'X-Skip-Interceptor': '1',
          },
        ),
      );

      // Parse tokens — JSON body first (test env), Set-Cookie fallback (prod env).
      String? newAccess  = response.data is Map
          ? response.data['access_token']?.toString()
          : null;
      String? newRefresh = response.data is Map
          ? response.data['refresh_token']?.toString()
          : null;

      if (newAccess == null || newAccess.isEmpty) {
        final cookies = response.headers.map['set-cookie'] ?? [];
        for (final c in cookies) {
          if (c.contains('access_token_cookie=')) {
            newAccess = _cookieValue('access_token_cookie', c);
          }
          if (c.contains('refresh_token_cookie=')) {
            newRefresh = _cookieValue('refresh_token_cookie', c);
          }
        }
      }

      if (newAccess != null && newAccess.isNotEmpty) {
        await EnvironmentService.instance.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh ?? storedRefresh,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String? _cookieValue(String name, String cookieStr) {
    for (final part in cookieStr.split(';')) {
      final t = part.trim();
      if (t.startsWith('$name=')) return t.substring(name.length + 1).trim();
    }
    return null;
  }
}
