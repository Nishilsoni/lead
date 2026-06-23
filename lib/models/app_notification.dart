import 'package:flutter/material.dart';

/// A single in-app notification / activity-feed entry.
///
/// Parsing is intentionally tolerant: the backend feed (currently the org
/// automation-log endpoint) returns `event_type` / `message` / `created_at`,
/// but a dedicated notifications endpoint may instead use `type`, `title`,
/// `is_read`, `lead_id`, etc. We read whichever keys are present so the same
/// model works against either contract.
class AppNotification {
  final String id;

  /// Raw event/type key from the API, e.g. "lead_stage_changed", "lead_won".
  final String type;

  /// Human title. Falls back to a prettified [type] when the API has none.
  final String title;

  /// Body text describing the event.
  final String message;

  final DateTime createdAt;

  /// Linked entity (usually a lead) the notification refers to, if any.
  final String? relatedId;

  /// Server-provided read flag, when the API tracks it. Null = unknown, in
  /// which case read-state is resolved from the local store.
  final bool? serverRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.relatedId,
    this.serverRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    String firstString(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    bool? readFlag() {
      // Timestamp-style: `read_at` present & non-null means it was read.
      for (final k in ['read_at', 'readAt', 'seen_at', 'seenAt']) {
        if (json.containsKey(k)) {
          final v = json[k];
          return v != null && v.toString().isNotEmpty;
        }
      }
      // Boolean-style fallback.
      for (final k in ['read', 'is_read', 'seen', 'is_seen']) {
        final v = json[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) return v.toLowerCase() == 'true';
      }
      return null;
    }

    final type = firstString(['event_type', 'type', 'category', 'kind']);
    final explicitTitle = firstString(['title', 'heading', 'name']);

    DateTime parsedDate() {
      final raw = firstString(['created_at', 'createdAt', 'timestamp', 'date']);
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }

    // Related entity can be at the top level or nested inside `data`.
    var relatedRaw = firstString([
      'related_id',
      'relatedId',
      'lead_id',
      'leadId',
      'reference_id',
    ]);
    if (relatedRaw.isEmpty && json['data'] is Map) {
      final data = json['data'] as Map;
      for (final k in ['lead_id', 'leadId', 'related_id', 'reference_id', 'id']) {
        final v = data[k];
        if (v != null && v.toString().isNotEmpty) {
          relatedRaw = v.toString();
          break;
        }
      }
    }

    return AppNotification(
      id: firstString(['id', '_id', 'uuid']),
      type: type,
      title: explicitTitle.isNotEmpty ? explicitTitle : _prettifyType(type),
      message: firstString(['message', 'body', 'description', 'detail']),
      createdAt: parsedDate(),
      relatedId: relatedRaw.isEmpty ? null : relatedRaw,
      serverRead: readFlag(),
    );
  }

  /// "lead_stage_changed" → "Lead stage changed"
  static String _prettifyType(String type) {
    if (type.isEmpty) return 'Notification';
    final words = type.replaceAll('-', '_').split('_').where((w) => w.isNotEmpty);
    final joined = words.join(' ').toLowerCase();
    if (joined.isEmpty) return 'Notification';
    return joined[0].toUpperCase() + joined.substring(1);
  }

  // ── Presentation helpers (icon + accent colour by event type) ──────────────

  IconData get icon {
    final t = type.toLowerCase();
    if (t.contains('won')) return Icons.emoji_events_rounded;
    if (t.contains('lost')) return Icons.cancel_rounded;
    if (t.contains('stage')) return Icons.swap_horiz_rounded;
    if (t.contains('appointment') || t.contains('meeting')) {
      return Icons.event_available_rounded;
    }
    if (t.contains('task')) return Icons.task_alt_rounded;
    if (t.contains('lead')) return Icons.person_add_alt_1_rounded;
    if (t.contains('payment') || t.contains('invoice')) {
      return Icons.receipt_long_rounded;
    }
    if (t.contains('whatsapp') || t.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color get accent {
    final t = type.toLowerCase();
    if (t.contains('won')) return const Color(0xFF10B981);
    if (t.contains('lost')) return const Color(0xFFEF4444);
    if (t.contains('stage')) return const Color(0xFF6366F1);
    if (t.contains('appointment') || t.contains('meeting')) {
      return const Color(0xFFF59E0B);
    }
    if (t.contains('payment') || t.contains('invoice')) {
      return const Color(0xFF0EA5E9);
    }
    return const Color(0xFF3B82F6);
  }
}
