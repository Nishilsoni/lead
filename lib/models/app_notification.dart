import 'dart:convert';

import 'package:flutter/material.dart';

/// What kind of record a notification refers to, classified from its
/// `event_type` (e.g. "lead_assigned", "task_due", "customer_updated").
/// Drives which screen [AppNavigator] opens on tap.
enum NotificationTargetType { lead, task, customer, unknown }

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

    final type = extractType(json);
    final explicitTitle = firstString(['title', 'heading', 'name']);

    DateTime parsedDate() {
      final raw = firstString(['created_at', 'createdAt', 'timestamp', 'date']);
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }

    return AppNotification(
      id: firstString(['id', '_id', 'uuid']),
      type: type,
      title: explicitTitle.isNotEmpty ? explicitTitle : _prettifyType(type),
      message: firstString(['message', 'body', 'description', 'detail']),
      createdAt: parsedDate(),
      relatedId: extractRelatedId(json),
      serverRead: readFlag(),
    );
  }

  /// Extracts the raw event/type string from a payload — same tolerant
  /// key-matching used by [fromJson], but shared with FCM `data` payloads
  /// too so a push tap can classify itself with [classify] below.
  static String extractType(Map<dynamic, dynamic> json) {
    String firstString(Map<dynamic, dynamic> map, List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    var type = firstString(json, [
      'event_type',
      'eventType',
      'type',
      'category',
      'kind',
    ]);
    final nested =
        _payloadMap(json['data']) ??
        _payloadMap(json['payload']) ??
        _payloadMap(json['notification']);
    if (type.isEmpty && nested != null) {
      type = firstString(nested, [
        'event_type',
        'eventType',
        'type',
        'category',
        'kind',
      ]);
    }
    return type;
  }

  /// FCM data values are strings, so a backend may send the linked record as
  /// a JSON string (for example `data: '{"lead": {"id": "..."}}'`).
  /// Treat those exactly like a nested map rather than requiring every sender
  /// to flatten its payload in the same way.
  static Map<dynamic, dynamic>? _payloadMap(dynamic value) {
    if (value is Map) return value;
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts a related-entity id (lead, appointment/task, or customer) from
  /// a raw event payload. Shared between the REST feed parser above and
  /// FCM/local-notification tap payloads, which describe the same backend
  /// events but aren't guaranteed to use identical key casing or nesting.
  ///
  /// [allowBareId]: a REST feed item's top-level `id` is the *notification's
  /// own* id, not the entity it refers to, so it's excluded there by default.
  /// An FCM `data` map has no such concept — pass true when parsing one, to
  /// also match a generic `{"event_type": ..., "id": ...}` shape.
  static String? extractRelatedId(
    Map<dynamic, dynamic> json, {
    bool allowBareId = false,
  }) {
    String firstString(Map<dynamic, dynamic> map, List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    var relatedRaw = firstString(json, [
      'related_id',
      'relatedId',
      'lead_id',
      'leadId',
      'task_id',
      'taskId',
      'appointment_id',
      'appointmentId',
      'customer_id',
      'customerId',
      'reference_id',
      'referenceId',
      'entity_id',
      'entityId',
      'record_id',
      'recordId',
      'resource_id',
      'resourceId',
      if (allowBareId) 'id',
    ]);
    final nested =
        _payloadMap(json['data']) ??
        _payloadMap(json['payload']) ??
        _payloadMap(json['notification']);
    if (relatedRaw.isEmpty && nested != null) {
      relatedRaw = firstString(nested, [
        'lead_id',
        'leadId',
        'task_id',
        'taskId',
        'appointment_id',
        'appointmentId',
        'customer_id',
        'customerId',
        'related_id',
        'relatedId',
        'reference_id',
        'referenceId',
        'entity_id',
        'entityId',
        'record_id',
        'recordId',
        'resource_id',
        'resourceId',
        'id',
      ]);

      // Some senders put the entity under `lead`/`related` instead of
      // flattening it. Pull its id too.
      if (relatedRaw.isEmpty) {
        for (final key in ['lead', 'related', 'entity', 'record', 'resource']) {
          final entity = _payloadMap(nested[key]);
          if (entity != null) {
            relatedRaw = firstString(entity, ['id', 'lead_id', 'leadId']);
            if (relatedRaw.isNotEmpty) break;
          }
        }
      }
    }

    if (relatedRaw.isEmpty) {
      for (final key in ['lead', 'related', 'entity', 'record', 'resource']) {
        final entity = _payloadMap(json[key]);
        if (entity != null) {
          relatedRaw = firstString(entity, ['id', 'lead_id', 'leadId']);
          if (relatedRaw.isNotEmpty) break;
        }
      }
    }
    return relatedRaw.isEmpty ? null : relatedRaw;
  }

  /// ID of the notification record itself, used as a fallback when a push
  /// does not carry the lead id but the in-app notification feed does.
  static String? extractNotificationId(Map<dynamic, dynamic> json) {
    String firstString(Map<dynamic, dynamic> map) {
      for (final key in [
        'notification_id',
        'notificationId',
        'alert_id',
        'alertId',
      ]) {
        final value = map[key];
        if (value != null && value.toString().isNotEmpty)
          return value.toString();
      }
      return '';
    }

    var id = firstString(json);
    final nested =
        _payloadMap(json['data']) ??
        _payloadMap(json['payload']) ??
        _payloadMap(json['notification']);
    if (id.isEmpty && nested != null) id = firstString(nested);
    return id.isEmpty ? null : id;
  }

  /// Classifies a raw `event_type` string into what kind of record it
  /// refers to, to decide which screen a tap should open.
  static NotificationTargetType classify(String? eventType) {
    final t = (eventType ?? '').toLowerCase();
    if (t.contains('task') ||
        t.contains('appointment') ||
        t.contains('meeting')) {
      return NotificationTargetType.task;
    }
    if (t.contains('customer')) return NotificationTargetType.customer;
    if (t.contains('lead')) return NotificationTargetType.lead;
    return NotificationTargetType.unknown;
  }

  /// [flutter_local_notifications] payloads are a single string, so a locally
  /// -displayed notification (foreground FCM banner, or an appointment
  /// reminder) needs both `event_type` and the related id packed into one —
  /// used by [NotificationService.showPushNotification] /
  /// [NotificationService.scheduleAppointmentNotification].
  static String encodeLocalPayload({
    String? eventType,
    required String relatedId,
  }) {
    return jsonEncode({'t': eventType, 'id': relatedId});
  }

  /// Reverses [encodeLocalPayload]. Also accepts a bare id string with no
  /// JSON wrapper — the format every appointment reminder used before this
  /// existed, which may still be sitting in already-scheduled OS
  /// notifications on a device that just updated.
  static ({String? eventType, String? relatedId}) decodeLocalPayload(
    String? payload,
  ) {
    if (payload == null || payload.isEmpty) {
      return (eventType: null, relatedId: null);
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final id = decoded['id']?.toString();
        return (
          eventType: decoded['t']?.toString(),
          relatedId: id != null && id.isNotEmpty ? id : null,
        );
      }
    } catch (_) {
      // Not JSON — legacy plain lead-id payload.
    }
    return (eventType: null, relatedId: payload);
  }

  /// "lead_stage_changed" → "Lead stage changed"
  static String _prettifyType(String type) {
    if (type.isEmpty) return 'Notification';
    final words = type
        .replaceAll('-', '_')
        .split('_')
        .where((w) => w.isNotEmpty);
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
