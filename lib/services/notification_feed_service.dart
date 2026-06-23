import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/app_notification.dart';

/// Talks to the in-app notifications API for the active org.
///
/// Distinct from [NotificationService] (local device push). The org id and
/// bearer token are injected by the [ApiClient] interceptor, and the base URL
/// switches by environment — so every call here works on both test and prod
/// with no path changes.
class NotificationFeedService {
  final ApiClient _client = ApiClient();

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// Fetches the feed. The list response includes `unread_count` inline, so we
  /// return both and avoid a second round-trip.
  Future<({List<AppNotification> items, int unreadCount})>
      fetchNotifications() async {
    try {
      final response = await _client.dio.get(ApiConstants.notifications);
      final data = response.data;

      List<dynamic> raw = [];
      int unread = 0;
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        for (final key in ['items', 'notifications', 'results', 'data', 'logs']) {
          if (data[key] is List) {
            raw = data[key] as List;
            break;
          }
        }
        unread = _intOf(data, ['unread_count', 'unread', 'count']);
      }

      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .where((n) => n.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return (items: list, unreadCount: unread);
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[NotificationFeed] list error: $e');
      throw _handleError(e);
    }
  }

  int _intOf(Map data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return 0;
  }

  // ── Mutations ───────────────────────────────────────────────────────────────

  Future<void> markRead(String id) =>
      _patch(ApiConstants.notificationRead(id));

  Future<void> markAllRead() => _patch(ApiConstants.notificationsReadAll);

  Future<void> clearAll() => _delete(ApiConstants.notificationsClearAll);

  Future<void> deleteOne(String id) =>
      _delete(ApiConstants.notificationById(id));

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _patch(String path) async {
    try {
      await _client.dio.patch(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _client.dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    return e.response?.data is Map
        ? (e.response?.data['detail']?.toString() ??
            'Could not load notifications')
        : 'Could not load notifications';
  }
}
