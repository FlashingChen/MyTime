import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Android notification channel used for timer reminders.
const timerReminderChannelId = 'timer_reminders';

/// Boundary between the app and the platform notification APIs.
///
/// Kept abstract so the timer logic can be tested without a plugin.
abstract interface class TimerNotificationService {
  /// Initializes the platform plugin and resolves the device timezone.
  /// Safe to call multiple times; best-effort on failure.
  Future<void> initialize();

  /// Asks the user for notification permission (no-op once granted).
  Future<void> requestPermission();

  /// Schedules a one-shot local notification for [when].
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  /// Removes all shown and pending notifications.
  Future<void> cancelAll();
}

/// [TimerNotificationService] backed by `flutter_local_notifications`.
class LocalNotificationsService implements TimerNotificationService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tz_data.initializeTimeZones();
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (error) {
      debugPrint('TimerNotificationService: timezone setup failed: $error');
    }
    try {
      // Permission is requested when the user enables reminders, not at
      // startup, so the app never prompts before the feature is used.
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.initialize(
            settings: const AndroidInitializationSettings(
              '@mipmap/ic_launcher',
            ),
          );
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.initialize(
            settings: const DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          );
    } catch (error) {
      debugPrint('TimerNotificationService: initialize failed: $error');
    }
  }

  @override
  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    } catch (error) {
      debugPrint('TimerNotificationService: requestPermission failed: $error');
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            timerReminderChannelId,
            '计时提醒',
            channelDescription: '计时进行中每隔一段时间提醒停止计时',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
          ),
        ),
        // Inexact alarms need no exact-alarm permission and are more
        // battery-friendly; a reminder that arrives a minute late is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('TimerNotificationService.schedule failed: $error');
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      await _plugin.cancelAllPendingNotifications();
    } catch (error) {
      debugPrint('TimerNotificationService.cancelAll failed: $error');
    }
  }
}
