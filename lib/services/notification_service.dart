import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/activity.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'appointments_channel';
  static const _channelName = 'Appointment Reminders';
  static const _channelDesc = 'Notifies 15 minutes before a scheduled meeting';

  // Server-pushed notifications (missed follow-up, appointment updated by
  // someone else, etc.) — distinct channel from the local appointment
  // reminders above. Must match the value in AndroidManifest.xml's
  // com.google.firebase.messaging.default_notification_channel_id meta-data,
  // which is what Android uses to display FCM notifications received while
  // the app is backgrounded/killed.
  static const _pushChannelId = 'push_channel';
  static const _pushChannelName = 'Notifications';
  static const _pushChannelDesc =
      'Notifications from OceanCRM (leads, follow-ups, appointments)';

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<void> requestPermissions() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> scheduleAppointmentNotification(
      Appointment appointment) async {
    print('[Notif] Scheduling for: ${appointment.note}, Scheduled at: ${appointment.scheduledAt}');
    if (!appointment.isScheduled) {
      print('[Notif] Not scheduled - status is ${appointment.status}');
      return;
    }

    final notifyAt =
        appointment.scheduledAt.subtract(const Duration(minutes: 15));
    print('[Notif] Notify time (15min before): $notifyAt, Now: ${DateTime.now()}, Is past? ${notifyAt.isBefore(DateTime.now())}');
    if (notifyAt.isBefore(DateTime.now())) {
      print('[Notif] Skipping - notification time is in the past');
      return;
    }

    final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);
    final notifId = appointment.id.hashCode.abs() % 2147483647;

    final businessName = appointment.business.name.isNotEmpty
        ? appointment.business.name
        : 'Lead';
    final body = appointment.note.isNotEmpty
        ? appointment.note
        : '${appointment.appointmentType} starts in 15 minutes';

    await _plugin.zonedSchedule(
      notifId,
      '${appointment.appointmentType} with $businessName in 15 min',
      body,
      tzNotifyAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleAllUpcoming(
      List<Appointment> appointments) async {
    for (final appt in appointments) {
      await scheduleAppointmentNotification(appt);
    }
  }

  static Future<void> cancelNotification(String appointmentId) async {
    await _plugin.cancel(appointmentId.hashCode.abs() % 2147483647);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Shows a notification immediately — used for FCM messages that arrive
  /// while the app is in the foreground, since Android/iOS don't auto-display
  /// a system notification for those (only for background/terminated).
  static Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _pushChannelId,
          _pushChannelName,
          channelDescription: _pushChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
