import 'package:flutter/foundation.dart';
import '../core/config/environment_service.dart';
import '../models/app_notification.dart';
import '../services/notification_feed_service.dart';

/// Drives the notification bell + panel against the server notifications API.
///
/// Read- and delete-state live on the server; actions here update the UI
/// optimistically and roll back if the request fails. State is keyed to the
/// active (env + org) so switching org refetches automatically.
class NotificationProvider extends ChangeNotifier {
  final NotificationFeedService _service = NotificationFeedService();

  List<AppNotification> _all = [];

  /// Optimistic "read" overlay applied on top of the server flags between a
  /// tap and the next reload. Cleared on reload (server becomes authoritative).
  final Set<String> _readIds = {};

  int? _serverUnread;
  bool _loading = false;
  String? _error;

  /// The (env+org) the current in-memory state belongs to, to detect switches.
  String? _loadedScope;

  bool get isLoading => _loading;
  String? get error => _error;

  List<AppNotification> get items => _all;

  bool isRead(AppNotification n) =>
      n.serverRead == true || _readIds.contains(n.id);

  int get _derivedUnread => _all.where((n) => !isRead(n)).length;

  /// Prefer the server count for the badge; fall back to the derived count.
  int get unreadCount => _serverUnread ?? _derivedUnread;

  bool get hasUnread => unreadCount > 0;

  String get _scope {
    final env = EnvironmentService.instance.current.name;
    final org = EnvironmentService.instance.activeOrgId ?? 'default';
    return '${env}_$org';
  }

  // ── Load / refresh ──────────────────────────────────────────────────────

  /// Loads feed + unread count. No-ops if already loaded for this org unless
  /// [refresh] is true. Re-fetches automatically when the active org changed.
  Future<void> load({bool refresh = false}) async {
    final scope = _scope;
    final scopeChanged = scope != _loadedScope;
    if (_loading) return;
    if (!refresh && !scopeChanged && _loadedScope != null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.fetchNotifications();
      _all = result.items;
      _serverUnread = result.unreadCount;
      _readIds.clear();
      _loadedScope = scope;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Actions (optimistic, with rollback) ───────────────────────────────────

  /// Mark a single notification read (e.g. on tap). No-op if already read.
  Future<void> markRead(String id) async {
    final target = _all.where((n) => n.id == id);
    if (target.isEmpty || isRead(target.first)) return;

    _readIds.add(id);
    if (_serverUnread != null && _serverUnread! > 0) _serverUnread = _serverUnread! - 1;
    notifyListeners();

    try {
      await _service.markRead(id);
    } catch (_) {
      _readIds.remove(id);
      if (_serverUnread != null) _serverUnread = _serverUnread! + 1;
      notifyListeners();
      rethrow;
    }
  }

  /// Mark every notification as read.
  Future<void> markAllRead() async {
    final prevRead = Set<String>.from(_readIds);
    final prevUnread = _serverUnread;

    _readIds.addAll(_all.map((n) => n.id));
    _serverUnread = 0;
    notifyListeners();

    try {
      await _service.markAllRead();
    } catch (_) {
      _readIds
        ..clear()
        ..addAll(prevRead);
      _serverUnread = prevUnread;
      notifyListeners();
      rethrow;
    }
  }

  /// Clear (delete) all notifications.
  Future<void> clearAll() async {
    final prevAll = List<AppNotification>.from(_all);
    final prevUnread = _serverUnread;

    _all = [];
    _serverUnread = 0;
    notifyListeners();

    try {
      await _service.clearAll();
    } catch (_) {
      _all = prevAll;
      _serverUnread = prevUnread;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a single notification.
  Future<void> deleteOne(String id) async {
    final idx = _all.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final removed = _all[idx];
    final wasUnread = !isRead(removed);

    _all = List<AppNotification>.from(_all)..removeAt(idx);
    if (wasUnread && _serverUnread != null && _serverUnread! > 0) {
      _serverUnread = _serverUnread! - 1;
    }
    notifyListeners();

    try {
      await _service.deleteOne(id);
    } catch (_) {
      _all = List<AppNotification>.from(_all)..insert(idx, removed);
      if (wasUnread && _serverUnread != null) _serverUnread = _serverUnread! + 1;
      notifyListeners();
      rethrow;
    }
  }
}
