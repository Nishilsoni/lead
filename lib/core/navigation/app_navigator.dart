import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../screens/leads/lead_detail_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../services/lead_service.dart';
import '../../services/notification_feed_service.dart';

/// Global navigator key so services that live outside the widget tree
/// (push notification taps, local notification taps) can push a screen
/// without a [BuildContext] of their own. Registered on [MaterialApp] in
/// main.dart.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  static final LeadService _leadService = LeadService();
  static final NotificationFeedService _notificationFeed =
      NotificationFeedService();

  /// A lead id that arrived (e.g. a cold-start notification tap) before the
  /// root [Navigator] finished attaching. Latest wins — only the most recent
  /// tap is worth honoring if several arrive before the navigator is ready.
  static String? _pendingLeadId;

  /// Entry point for notification taps: classifies the event by
  /// `event_type` (lead / task / customer) and opens whatever screen that
  /// record belongs to — or, if the payload carried no usable id (e.g. a
  /// backend payload gap we can't control), falls back to the notifications
  /// feed instead of silently doing nothing when the user taps.
  ///
  /// Task (appointment) and customer events both resolve to
  /// [LeadDetailScreen] today, same as a plain lead event — this app has
  /// no separate appointment-detail or customer screen; an appointment card
  /// can open activities from the lead detail page (see
  /// appointments_screen.dart's `_openLead`). The branches are kept explicit
  /// so each can point elsewhere the moment a dedicated screen exists,
  /// instead of silently lumping every event type together.
  static Future<void> openNotificationTarget(
    String? eventType,
    String? relatedId,
  ) {
    if (relatedId == null || relatedId.isEmpty) {
      return openNotificationsFeed();
    }
    switch (AppNotification.classify(eventType)) {
      case NotificationTargetType.lead:
      case NotificationTargetType.task:
      case NotificationTargetType.customer:
      case NotificationTargetType.unknown:
        return openLead(relatedId);
    }
  }

  /// Routes a remote push directly to its lead.  Most pushes carry a lead id,
  /// but older/current backend senders may only carry `notification_id`; in
  /// that case, resolve the notification from the feed first. This preserves
  /// a one-tap experience instead of making the user find the same item in
  /// the notification screen.
  static Future<void> openPushNotificationTarget(
    Map<dynamic, dynamic> payload,
  ) async {
    final eventType = AppNotification.extractType(payload);
    final relatedId = AppNotification.extractRelatedId(
      payload,
      allowBareId: true,
    );
    if (relatedId != null && relatedId.isNotEmpty) {
      return openNotificationTarget(eventType, relatedId);
    }

    final notificationId = AppNotification.extractNotificationId(payload);
    if (notificationId != null) {
      try {
        final result = await _notificationFeed.fetchNotifications();
        for (final notification in result.items) {
          if (notification.id == notificationId &&
              notification.relatedId != null &&
              notification.relatedId!.isNotEmpty) {
            return openNotificationTarget(
              notification.type,
              notification.relatedId,
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AppNavigator] notification target lookup failed: $e');
        }
      }
    }
    return openNotificationsFeed();
  }

  static Future<void> openNotificationsFeed() async {
    final navState = key.currentState;
    if (navState == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => openNotificationsFeed(),
      );
      return;
    }
    navState.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  /// Opens the lead a notification refers to. Notifications only carry an
  /// id, so the lead is fetched first for its name/assignee before pushing
  /// [LeadDetailScreen].
  static Future<void> openLead(String leadId) async {
    if (leadId.isEmpty) return;
    final navState = key.currentState;
    if (navState == null) {
      // Navigator not attached yet — this happens when a cold-start tap is
      // processed before the first frame builds. Queue it and retry once
      // the navigator is up instead of dropping it.
      if (kDebugMode) {
        debugPrint('[AppNavigator] navigator not ready, queuing lead $leadId');
      }
      _pendingLeadId = leadId;
      _retryPending();
      return;
    }
    await _push(navState, leadId);
  }

  static void _retryPending() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leadId = _pendingLeadId;
      if (leadId == null) return;
      final navState = key.currentState;
      if (navState == null) {
        _retryPending();
        return;
      }
      _pendingLeadId = null;
      _push(navState, leadId);
    });
  }

  static Future<void> _push(NavigatorState navState, String leadId) async {
    try {
      final lead = await _leadService.getLeadById(leadId);
      navState.push(
        MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
      );
    } catch (e) {
      // Lead may have been deleted or reassigned out of view, or the fetch
      // failed (offline, expired session, etc). Don't crash on a stale
      // notification tap, but don't fail silently either — the user tapped
      // a notification and nothing happening with no explanation is
      // confusing.
      if (kDebugMode) {
        debugPrint('[AppNavigator] openLead($leadId) failed: $e');
      }
      if (navState.mounted) {
        ScaffoldMessenger.maybeOf(navState.context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn\'t open that lead. It may have been removed or reassigned.',
            ),
          ),
        );
      }
    }
  }
}
