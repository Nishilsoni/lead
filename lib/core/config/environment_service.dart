import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_environment.dart';

class EnvironmentService extends ChangeNotifier {
  EnvironmentService._();
  static final EnvironmentService instance = EnvironmentService._();

  static const _prefKey = 'selected_environment';
  // Pre-known org ID for the test environment
  static const _testOrgId = '0199d939-d1cd-7001-add3-8991fb795d55';

  final _storage = const FlutterSecureStorage();

  AppEnvironment _current = AppEnvironment.prod;
  AppEnvironment get current => _current;
  bool get isProd => _current == AppEnvironment.prod;
  String get baseUrl => _current.baseUrl;

  /// Load persisted environment on app start. Must be called before runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _current = saved == AppEnvironment.test.name
        ? AppEnvironment.test
        : AppEnvironment.prod;

    // Seed the known test org ID so test env works without an extra API call
    final existing = await _storage.read(key: AppEnvironment.test.orgIdKey);
    if (existing == null) {
      await _storage.write(
          key: AppEnvironment.test.orgIdKey, value: _testOrgId);
    }
  }

  // ── Token helpers (all env-specific) ─────────────────────────────

  Future<String?> getAccessToken() =>
      _storage.read(key: _current.accessTokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: _current.refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _current.accessTokenKey, value: accessToken);
    await _storage.write(key: _current.refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _current.accessTokenKey);
    await _storage.delete(key: _current.refreshTokenKey);
  }

  Future<bool> get hasTokens async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }

  // ── Org ID (env-specific) ─────────────────────────────────────────

  Future<String?> getOrgId() => _storage.read(key: _current.orgIdKey);

  Future<void> setOrgId(String orgId) =>
      _storage.write(key: _current.orgIdKey, value: orgId);

  // ── Environment switching ─────────────────────────────────────────

  Future<void> switchTo(AppEnvironment env) async {
    if (_current == env) return;
    _current = env;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, env.name);
    notifyListeners();
  }
}
