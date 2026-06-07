import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/environment_service.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/auth.dart';
import '../models/org.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<LoginResponse> login(AuthCredentials credentials) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.login,
        data: credentials.toJson(),
      );

      final loginResponse = LoginResponse.fromJson(response.data);

      // Primary: tokens in JSON body (test env)
      String? accessToken = loginResponse.accessToken;
      String? refreshToken = loginResponse.refreshToken;

      // Fallback: tokens set as HttpOnly cookies in Set-Cookie headers (prod env)
      if (accessToken == null || accessToken.isEmpty) {
        final cookies = response.headers.map['set-cookie'] ?? [];
        for (final cookie in cookies) {
          if (accessToken == null && cookie.contains('access_token_cookie=')) {
            accessToken = _extractCookieValue('access_token_cookie', cookie);
          }
          if (refreshToken == null && cookie.contains('refresh_token_cookie=')) {
            refreshToken = _extractCookieValue('refresh_token_cookie', cookie);
          }
        }
      }

      if (accessToken == null || accessToken.isEmpty) {
        throw 'Login failed: server did not return an access token. '
            'Please check your credentials or contact support.';
      }

      await _client.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
      );

      // Discover and store all orgs for this environment
      await _discoverOrgs(accessToken);

      return loginResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetches all orgs the user belongs to and stores them.
  /// Also sets the active org ID (first org or JWT-derived one).
  Future<void> _discoverOrgs(String accessToken) async {
    // Log JWT claims to help diagnose multi-org issues
    if (kDebugMode) {
      final claims = _decodeJwtPayload(accessToken);
      debugPrint('[Auth] JWT claims: $claims');
    }

    // ── Strategy 1: GET /v1/org/current → full org list ──────────────
    try {
      final res = await _client.dio.get(ApiConstants.currentOrg);
      if (kDebugMode) debugPrint('[Auth] /org/current raw: ${res.data}');

      final raw = res.data is List
          ? res.data as List
          : res.data is Map && res.data['items'] is List
              ? res.data['items'] as List
              : <dynamic>[];

      final orgs = raw
          .whereType<Map<String, dynamic>>()
          .map(Org.fromJson)
          .where((o) => o.id.isNotEmpty)
          .toList();

      if (orgs.isNotEmpty) {
        await EnvironmentService.instance.saveOrgList(orgs);
        final claims = _decodeJwtPayload(accessToken);
        final jwtOrgId = _findOrgIdInClaims(claims);
        final activeId = (jwtOrgId != null &&
                orgs.any((o) => o.id == jwtOrgId))
            ? jwtOrgId
            : orgs.first.id;
        await EnvironmentService.instance.setOrgId(activeId);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] /org/current error: $e');
    }

    // ── Strategy 2: JWT claims fallback ──────────────────────────────
    final claims = _decodeJwtPayload(accessToken);
    final jwtOrgId = _findOrgIdInClaims(claims);
    if (jwtOrgId != null) {
      await EnvironmentService.instance.setOrgId(jwtOrgId);
      return;
    }

    // ── Strategy 3: GET /v1/user/logged ──────────────────────────────
    try {
      final res = await _client.dio.get(ApiConstants.currentUser);
      if (kDebugMode) debugPrint('[Auth] /user/logged raw: ${res.data}');
      if (res.data is Map) {
        final data = res.data as Map<String, dynamic>;
        final orgId = (data['org_id'] ??
                data['organization_id'] ??
                (data['org'] is Map ? (data['org'] as Map)['id'] : null))
            ?.toString();
        if (orgId != null && orgId.isNotEmpty) {
          await EnvironmentService.instance.setOrgId(orgId);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] /user/logged error: $e');
    }
  }

  /// Decodes the JWT payload (middle segment) into a claim map.
  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      String payload = parts[1]
          .replaceAll('-', '+')
          .replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Looks for an org ID under common claim names in JWT payload.
  String? _findOrgIdInClaims(Map<String, dynamic> claims) {
    for (final key in [
      'org_id',
      'organization_id',
      'tenant_id',
      'orgId',
      'org',
    ]) {
      final val = claims[key];
      if (val == null) continue;
      if (val is Map) {
        final id = val['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      } else {
        final s = val.toString();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await _client.dio.post(ApiConstants.logout);
    } catch (_) {}
    await _client.clearTokens();
  }

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

  Future<bool> isAuthenticated() => _client.hasTokens;

  /// Parses "name=value; Path=/; HttpOnly..." → returns "value"
  String? _extractCookieValue(String name, String cookieStr) {
    for (final part in cookieStr.split(';')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$name=')) {
        return trimmed.substring(name.length + 1).trim();
      }
    }
    return null;
  }

  String _handleError(DioException e) {
    if (e.response?.statusCode == 401) return 'Invalid email or password';
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
