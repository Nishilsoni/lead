import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_environment.dart';
import '../../models/org.dart';

class EnvironmentService extends ChangeNotifier {
  EnvironmentService._();
  static final EnvironmentService instance = EnvironmentService._();

  static const _prefKey = 'selected_environment';
  static const _testOrgId = '0199d939-d1cd-7001-add3-8991fb795d55';

  final _storage = const FlutterSecureStorage();

  AppEnvironment _current = AppEnvironment.prod;
  AppEnvironment get current => _current;
  bool get isProd => _current == AppEnvironment.prod;
  String get baseUrl => _current.baseUrl;

  // In-memory org list cache — populated after login and on org fetch
  List<Org> _orgList = [];
  List<Org> get orgList => List.unmodifiable(_orgList);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _current = saved == AppEnvironment.test.name
        ? AppEnvironment.test
        : AppEnvironment.prod;

    // Seed known test org ID
    final existing = await _storage.read(key: AppEnvironment.test.orgIdKey);
    if (existing == null) {
      await _storage.write(
          key: AppEnvironment.test.orgIdKey, value: _testOrgId);
    }

    // Restore org list cache from prefs
    _orgList = await _loadOrgList();
  }

  // ── Token helpers ─────────────────────────────────────────────────

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

  // ── Saved credentials (for silent re-login after token expiry) ───────

  String get _passwordKey => '${_current.name}_last_password';

  /// Stores the last-used password securely so the interceptor can
  /// silently re-login when the refresh token is also expired.
  Future<void> savePassword(String password) =>
      _storage.write(key: _passwordKey, value: password);

  Future<String?> getSavedPassword() =>
      _storage.read(key: _passwordKey);

  /// Last-used email — stored by the login screen in SharedPreferences.
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_login_email');
  }

  // ── Active org ID ─────────────────────────────────────────────────

  Future<String?> getOrgId() => _storage.read(key: _current.orgIdKey);

  Future<void> setOrgId(String orgId) =>
      _storage.write(key: _current.orgIdKey, value: orgId);

  // ── Org list ──────────────────────────────────────────────────────

  String get _orgListPrefKey => '${_current.name}_org_list';

  Future<List<Org>> _loadOrgList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_orgListPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Org.fromJson)
          .where((o) => o.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOrgList(List<Org> orgs) async {
    _orgList = orgs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _orgListPrefKey,
      jsonEncode(orgs.map((o) => o.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Returns the name of the currently active org.
  Future<String> getActiveOrgName() async {
    final activeId = await getOrgId();
    if (activeId == null || _orgList.isEmpty) return '';
    try {
      return _orgList.firstWhere((o) => o.id == activeId).name;
    } catch (_) {
      return _orgList.first.name;
    }
  }

  /// Switch to a different org within the same environment.
  /// Updates the stored org ID and notifies listeners so the UI rebuilds.
  Future<void> switchOrg(String orgId) async {
    await setOrgId(orgId);
    notifyListeners();
  }

  // ── Environment switching ─────────────────────────────────────────

  Future<void> switchTo(AppEnvironment env) async {
    if (_current == env) return;
    _current = env;
    _orgList = await _loadOrgList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, env.name);
    notifyListeners();
  }
}
