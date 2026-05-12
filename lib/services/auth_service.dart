import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/auth.dart';

/// Service layer for authentication operations.
class AuthService {
  final ApiClient _client = ApiClient();

  /// Authenticate with email/password. Returns login response and persists tokens.
  Future<LoginResponse> login(AuthCredentials credentials) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.login,
        data: credentials.toJson(),
      );

      final loginResponse = LoginResponse.fromJson(response.data);

      if (loginResponse.accessToken != null &&
          loginResponse.refreshToken != null) {
        await _client.saveTokens(
          accessToken: loginResponse.accessToken!,
          refreshToken: loginResponse.refreshToken!,
        );
      }

      return loginResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Log out and clear stored tokens.
  Future<void> logout() async {
    try {
      await _client.dio.post(ApiConstants.logout);
    } catch (_) {
      // Even if the API call fails, clear local tokens
    }
    await _client.clearTokens();
  }

  /// Refresh the access token using the stored refresh token.
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _client.refreshToken;
      if (refreshToken == null) return false;

      final response = await _client.dio.post(
        ApiConstants.refresh,
        options: Options(
          headers: {'Cookie': 'refresh_token_cookie=$refreshToken'},
        ),
      );

      final data = response.data;
      if (data['access_token'] != null) {
        await _client.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'] ?? refreshToken,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if the user has stored tokens (i.e., may still be authenticated).
  Future<bool> isAuthenticated() async {
    return _client.hasTokens;
  }

  String _handleError(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Invalid email or password';
    }
    if (e.response?.statusCode == 422) {
      final detail = e.response?.data?['detail'];
      if (detail is List && detail.isNotEmpty) {
        return detail.first['msg'] ?? 'Validation error';
      }
      return 'Validation error';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    return e.response?.data?['detail'] ?? 'Something went wrong';
  }
}
