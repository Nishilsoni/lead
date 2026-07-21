import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/config/environment_service.dart';
import '../core/config/firebase_env_options.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import 'notification_service.dart';

/// Registers this device with the backend (via FCM) so server-side events —
/// missed follow-up, appointment updated by someone else, lead assigned,
/// etc. — reach the phone as a real system notification instead of only
/// showing up in the feed next time [NotificationFeedService] is polled.
///
/// [initialize] must run after `Firebase.initializeApp()` and after the user
/// is authenticated, since token registration needs a bearer token + org id
/// (supplied by [ApiClient]'s interceptor).
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // A getter, not a field initializer: `FirebaseMessaging.instance` throws
  // immediately if no Firebase app has been configured for this platform
  // (e.g. iOS before GoogleService-Info.plist is added). Deferring the
  // lookup keeps that failure inside initialize()'s try/catch below instead
  // of blowing up the moment this singleton is first touched.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final ApiClient _client = ApiClient();
  String? _lastRegisteredToken;
  bool _listenersAttached = false;
  String? _configuredProjectId;

  Future<void> initialize() async {
    // Make sure Firebase is initialized for the currently-selected environment
    // (test/prod from the login screen). If the user switched environments,
    // this tears down the old project and re-inits with the new one so the
    // FCM token below belongs to the backend we're actually talking to.
    try {
      await initFirebaseForEnvironment(EnvironmentService.instance.current);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] Firebase init failed: $e');
      return;
    }
    if (Firebase.apps.isEmpty) {
      if (kDebugMode) debugPrint('[Push] Firebase not configured, skipping');
      return;
    }

    // If the active project changed since last time, re-attach listeners and
    // forget the old token (it belonged to the previous project).
    final projectId = Firebase.app().options.projectId;
    if (projectId != _configuredProjectId) {
      _listenersAttached = false;
      _lastRegisteredToken = null;
      _configuredProjectId = projectId;
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('[Push] permission: ${settings.authorizationStatus}');
      }

      if (!_listenersAttached) {
        _listenersAttached = true;
        // Foreground: FCM does not auto-display a system notification, so
        // show one ourselves via the same local-notifications plugin used
        // for appointment reminders.
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        // Backgrounded app, user tapped the system notification.
        FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);
        _messaging.onTokenRefresh.listen(_registerToken);
      }

      // App was fully killed and launched by tapping the notification.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _onNotificationTap(initialMessage);

      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] initialize failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    NotificationService.showPushNotification(
      id: message.hashCode,
      title: notification.title ?? 'OceanCRM',
      body: notification.body ?? '',
      payload: message.data['notification_id']?.toString(),
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    // Deep-link target (lead/appointment id) travels in message.data.
    // Wire this up to navigation once there's a route that can jump
    // straight to a lead/appointment from a notification id.
    if (kDebugMode) debugPrint('[Push] tapped: ${message.data}');
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;
    try {
      await _client.dio.post(ApiConstants.deviceTokens, data: {
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      _lastRegisteredToken = token;
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] token registration failed: $e');
    }
  }

  /// Best-effort: tell the backend to stop pushing to this device.
  Future<void> unregister() async {
    final token = _lastRegisteredToken;
    if (token == null) return;
    try {
      // DELETE carries the token in the request body (not a query param),
      // per the backend contract.
      await _client.dio.delete(
        ApiConstants.deviceTokens,
        data: {'fcm_token': token},
      );
    } catch (_) {
      // Non-fatal — a stale token just means one extra failed push later.
    }
    _lastRegisteredToken = null;
  }
}

/// Must be a top-level function — FCM invokes this in a background isolate
/// when the app is backgrounded/terminated. Registered once in main().
///
/// The isolate is fresh, so Firebase must be initialized here too. It reads the
/// persisted environment directly (SharedPreferences works in the background
/// isolate) to pick the matching project's options.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final env = await EnvironmentService.persistedEnvironment();
  await initFirebaseForEnvironment(env);
}
