import 'package:flutter/foundation.dart';

/// Shared, in-memory Facebook connection state.
///
/// The two Facebook submodules — Marketing → "Ad Accounts" and Administration →
/// "Auto Import Accounts" — are separate screens but share one Facebook login.
/// After a successful OAuth login on either screen we cache the short-lived user
/// access token here so the other screen can reuse it (skipping a second login,
/// mirroring the web's "Continue as …" behaviour) and so both can reflect a
/// single "Connected to Facebook" status.
///
/// The token is implicit-flow and short-lived, so it's kept in memory only for
/// the current session and treated as usable for [_sessionWindow].
class FacebookConnection extends ChangeNotifier {
  FacebookConnection._();
  static final FacebookConnection instance = FacebookConnection._();

  /// How long a cached login token is reused before requiring a fresh login.
  static const Duration _sessionWindow = Duration(minutes: 50);

  String? _userToken;
  DateTime? _obtainedAt;

  /// The cached user token if still within the session window, else null.
  String? get userToken {
    if (_userToken == null || _obtainedAt == null) return null;
    if (DateTime.now().difference(_obtainedAt!) > _sessionWindow) {
      return null;
    }
    return _userToken;
  }

  /// True when a usable Facebook login token is cached this session.
  bool get hasActiveLogin => userToken != null;

  /// Cache a freshly obtained Facebook user token (after OAuth login).
  void setUserToken(String token) {
    _userToken = token;
    _obtainedAt = DateTime.now();
    notifyListeners();
  }

  /// Forget the cached login (e.g. user chose "Log into another account").
  void clear() {
    _userToken = null;
    _obtainedAt = null;
    notifyListeners();
  }
}
