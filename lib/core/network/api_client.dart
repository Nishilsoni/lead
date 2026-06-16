import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/environment_service.dart';
import '../constants/api_constants.dart';

/// Key used in RequestOptions.extra to tell the interceptor to skip
/// injecting x-org-id (needed for /org/current which returns ALL orgs).
const _kSkipOrgId = 'skipOrgId';

class ApiClient {
  ApiClient._internal();
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;

  /// Called when both token refresh AND silent re-login fail.
  /// Wire this to AuthProvider.logout() from AuthGate.
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
      LogInterceptor(requestBody: true, responseBody: true, logPrint: (obj) {}),
    ]);

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

class _AuthRefreshInterceptor extends Interceptor {
  /// Single-flight refresh lock. While a refresh is in progress, every other
  /// request awaits this same future instead of firing its own refresh.
  /// This is what makes waking the app after the 6-hour expiry seamless:
  /// the dozens of requests that fire at once all share ONE refresh, then retry.
  Future<bool>? _refreshFuture;

  /// Refresh proactively when the access token has this many seconds (or less)
  /// of life remaining — so requests almost never hit a 401 in the first place.
  static const int _expiryBufferSeconds = 120;

  /// Marks a request that has already been retried once after a refresh, so a
  /// repeated 401 can't spin into an infinite refresh→retry→401 loop.
  static const String _kRetried = '__authRetried';

  Dio get _dio => ApiClient.instance.dio;

  // ── Request ─────────────────────────────────────────────────────────

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final env = EnvironmentService.instance;
    options.baseUrl = env.baseUrl;

    final isAuthPath = options.path.contains('/auth/');

    // ── Proactive refresh ─────────────────────────────────────────────
    // If the stored access token is expired or about to expire, refresh it
    // BEFORE sending the request. Keeps the session feeling alive forever.
    if (!isAuthPath) {
      var token = await env.getAccessToken();
      if (token != null && token.isNotEmpty && _isExpiringSoon(token)) {
        await _ensureRefreshed();
      }
    }

    // Inject bearer token + cookie (re-read in case it was just refreshed)
    final token = await env.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Cookie'] = 'access_token_cookie=$token';
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Inject x-org-id for data endpoints.
    // Skip for: auth paths, /org/current (returns ALL orgs — filtering breaks it),
    // and any caller that sets extra[_kSkipOrgId] = true.
    final skip = isAuthPath ||
        options.path.contains('/org/current') ||
        options.extra[_kSkipOrgId] == true;

    if (!skip) {
      final orgId = await env.getOrgId();
      if (orgId != null && orgId.isNotEmpty) {
        options.headers['x-org-id'] = orgId;
      }
    }

    handler.next(options);
  }

  // ── 401 handling: refresh → silent re-login → logout ────────────────

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    final isAuthPath = err.requestOptions.path.contains('/auth/');
    final alreadyRetried = err.requestOptions.extra[_kRetried] == true;

    if (is401 && !isAuthPath && !alreadyRetried) {
      try {
        // All concurrent 401s funnel through one shared refresh.
        final ok = await _ensureRefreshed();
        if (ok) {
          final opts = err.requestOptions;
          opts.extra[_kRetried] = true;
          final newToken = await EnvironmentService.instance.getAccessToken();
          if (newToken != null && newToken.isNotEmpty) {
            opts.headers['Cookie'] = 'access_token_cookie=$newToken';
            opts.headers['Authorization'] = 'Bearer $newToken';
          }
          handler.resolve(await _dio.fetch(opts));
          return;
        }
      } catch (_) {
        // fall through to logout
      }

      // Both refresh and silent re-login failed (password likely changed)
      await EnvironmentService.instance.clearTokens();
      ApiClient.onUnauthorized?.call();
    }

    handler.next(err);
  }

  // ── Single-flight refresh ────────────────────────────────────────────

  /// Returns a shared refresh future. The first caller kicks off the work;
  /// every caller that arrives while it is in flight awaits the same result.
  Future<bool> _ensureRefreshed() {
    return _refreshFuture ??=
        _runRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<bool> _runRefresh() async {
    // Step 1: refresh token. Step 2: silent re-login with stored credentials.
    bool ok = await _doRefresh();
    if (!ok) ok = await _doSilentReLogin();
    return ok;
  }

  // ── JWT expiry ───────────────────────────────────────────────────────

  /// True if the JWT is expired or within [_expiryBufferSeconds] of expiring.
  /// If the token has no readable `exp`, returns false (let 401 handling cover it).
  bool _isExpiringSoon(String token) {
    final exp = _jwtExp(token);
    if (exp == null) return false;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return exp - nowSec <= _expiryBufferSeconds;
  }

  /// Decodes the `exp` (seconds since epoch) claim from a JWT, or null.
  int? _jwtExp(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final map =
          jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is int) return exp;
      if (exp is num) return exp.toInt();
      return int.tryParse(exp?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  // ── Refresh token ────────────────────────────────────────────────────

  Future<bool> _doRefresh() async {
    final stored = await EnvironmentService.instance.getRefreshToken();
    if (stored == null || stored.isEmpty) return false;
    try {
      final response = await _plainDio().post(
        ApiConstants.refresh,
        options: Options(
          headers: {'Cookie': 'refresh_token_cookie=$stored'},
        ),
      );
      return _saveTokensFromResponse(response, stored);
    } catch (_) {
      return false;
    }
  }

  // ── Silent re-login with stored credentials ──────────────────────────

  Future<bool> _doSilentReLogin() async {
    final env = EnvironmentService.instance;
    final email = await env.getSavedEmail();
    final password = await env.getSavedPassword();
    if (email == null || email.isEmpty) return false;
    if (password == null || password.isEmpty) return false;

    try {
      final response = await _plainDio().post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      return _saveTokensFromResponse(response, null);
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// A plain Dio without our interceptors — used for auth calls to avoid loops.
  Dio _plainDio() => Dio(BaseOptions(
        baseUrl: EnvironmentService.instance.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

  bool _saveTokensFromResponse(Response response, String? fallbackRefresh) {
    String? access = response.data is Map
        ? response.data['access_token']?.toString()
        : null;
    String? refresh = response.data is Map
        ? response.data['refresh_token']?.toString()
        : null;

    if (access == null || access.isEmpty) {
      for (final c in response.headers.map['set-cookie'] ?? <String>[]) {
        if (c.contains('access_token_cookie=')) {
          access = _cookieValue('access_token_cookie', c);
        }
        if (c.contains('refresh_token_cookie=')) {
          refresh = _cookieValue('refresh_token_cookie', c);
        }
      }
    }

    if (access == null || access.isEmpty) return false;

    EnvironmentService.instance.saveTokens(
      accessToken: access,
      refreshToken: refresh ?? fallbackRefresh ?? '',
    );
    return true;
  }

  String? _cookieValue(String name, String cookieStr) {
    for (final part in cookieStr.split(';')) {
      final t = part.trim();
      if (t.startsWith('$name=')) return t.substring(name.length + 1).trim();
    }
    return null;
  }
}
