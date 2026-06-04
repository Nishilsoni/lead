import 'package:dio/dio.dart';
import '../config/environment_service.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  static ApiClient get instance => _instance;

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
      _EnvInterceptor(),
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

/// Injects auth headers, org-id, and always uses the current environment's baseUrl.
class _EnvInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final env = EnvironmentService.instance;

    // Keep requests pointed at whichever env is currently active
    options.baseUrl = env.baseUrl;

    // Inject bearer token + cookie
    final token = await env.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Cookie'] = 'access_token_cookie=$token';
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Inject org-id for non-auth endpoints
    if (!options.path.contains('/auth/')) {
      final orgId = await env.getOrgId();
      if (orgId != null && orgId.isNotEmpty) {
        options.headers['x-org-id'] = orgId;
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
