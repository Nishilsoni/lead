import 'package:flutter/material.dart';

/// The two data sources the calendar aggregates.
/// [appointment] → /v1/appointment  (web "Task & Appointment")
/// [activity]    → /v1/interaction  (web "Activity")
enum CalendarEventType { appointment, activity }

/// A unified event used by the calendar, mapped from either an
/// Appointment or an Interaction so both can live on the same grid.
class CalendarEvent {
  final String id;
  final CalendarEventType type;
  final String category; // appointment_type / interaction_type (e.g. Call, Meeting)
  final String leadName; // business / contact name
  final String? leadId; // appointments expose this; activities may not
  final DateTime dateTime; // scheduled_at / interacted_at (local)
  final String note;
  final String? status; // appointments only: SCHEDULED / COMPLETED / CANCELLED
  final String assigneeId;
  final String assigneeName;

  const CalendarEvent({
    required this.id,
    required this.type,
    required this.category,
    required this.leadName,
    required this.dateTime,
    required this.note,
    required this.assigneeId,
    required this.assigneeName,
    this.leadId,
    this.status,
  });

  // ── Appointment mapping ───────────────────────────────────────────
  factory CalendarEvent.fromAppointment(Map<String, dynamic> json) {
    final business = json['business'] as Map<String, dynamic>? ?? {};
    final user = json['assigned_user'] as Map<String, dynamic>? ?? {};
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      type: CalendarEventType.appointment,
      category: (json['appointment_type'] ?? 'Appointment').toString(),
      leadName: (business['business']?.toString().isNotEmpty == true
              ? business['business']
              : business['name'] ?? 'Lead')
          .toString(),
      leadId: json['lead_id']?.toString(),
      dateTime: DateTime.tryParse(json['scheduled_at'] ?? '')?.toLocal() ??
          DateTime.now(),
      note: (json['note'] ?? '').toString(),
      status: (json['status'] ?? 'SCHEDULED').toString(),
      assigneeId: (user['id'] ?? '').toString(),
      assigneeName: (user['name'] ?? 'Unassigned').toString(),
    );
  }

  // ── Interaction (activity) mapping ────────────────────────────────
  factory CalendarEvent.fromInteraction(Map<String, dynamic> json) {
    final business = json['business'] as Map<String, dynamic>? ?? {};
    final user = json['interacted_by_user'] as Map<String, dynamic>? ?? {};
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      type: CalendarEventType.activity,
      category: (json['interaction_type'] ?? 'Activity').toString(),
      leadName: (business['business']?.toString().isNotEmpty == true
              ? business['business']
              : business['name'] ?? 'Lead')
          .toString(),
      leadId: json['lead_id']?.toString(),
      dateTime: DateTime.tryParse(json['interacted_at'] ?? '')?.toLocal() ??
          DateTime.now(),
      note: (json['note'] ?? '').toString(),
      status: null,
      assigneeId: (user['id'] ?? '').toString(),
      assigneeName: (user['name'] ?? 'Unknown').toString(),
    );
  }

  bool get isAppointment => type == CalendarEventType.appointment;
  bool get isActivity => type == CalendarEventType.activity;

  DateTime get dayKey => DateTime(dateTime.year, dateTime.month, dateTime.day);

  // ── Presentation ──────────────────────────────────────────────────

  /// Colour by category (shared with the lead-activity cards).
  Color get color {
    switch (category) {
      case 'Call':
        return const Color(0xFF10B981);
      case 'Meeting':
        return const Color(0xFF3B82F6);
      case 'Online':
        return const Color(0xFF8B5CF6);
      case 'Email':
        return const Color(0xFFF59E0B);
      case 'Message':
        return const Color(0xFF06B6D4);
      default:
        return isAppointment
            ? const Color(0xFF1A73E8)
            : const Color(0xFF6B7280);
    }
  }

  IconData get icon {
    switch (category) {
      case 'Call':
        return Icons.phone_rounded;
      case 'Meeting':
        return Icons.groups_rounded;
      case 'Online':
        return Icons.videocam_rounded;
      case 'Email':
        return Icons.email_rounded;
      case 'Message':
        return Icons.chat_bubble_rounded;
      default:
        return isAppointment ? Icons.event_rounded : Icons.history_rounded;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }
}
