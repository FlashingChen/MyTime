import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/services/timer_notification_service.dart';
import 'package:mytime/data/services/timer_reminder_scheduler.dart';

void main() {
  late _RecordingNotificationService notifications;
  late TimerReminderScheduler scheduler;
  late DateTime start;
  late DateTime now; // Injected clock; configure() must be deterministic.

  AppSettings settings({
    bool enabled = true,
    int intervalMinutes = 30,
  }) => AppSettings(
    reminderEnabled: enabled,
    reminderIntervalMinutes: intervalMinutes,
  );

  setUp(() {
    notifications = _RecordingNotificationService();
    now = DateTime(2026, 8, 11, 9, 0);
    scheduler = TimerReminderScheduler(notifications, clock: () => now);
    start = DateTime(2026, 8, 11, 9, 0);
    scheduler.configure(settings());
  });

  group('TimerReminderScheduler', () {
    test('schedules the first reminder at start + interval', () {
      scheduler.sync(start, start);

      expect(notifications.scheduled, hasLength(1));
      final reminder = notifications.scheduled.single;
      expect(reminder.id, timerReminderNotificationId);
      expect(reminder.when, start.add(const Duration(minutes: 30)));
      expect(reminder.body, contains('30 分钟'));
    });

    test('does not reschedule before the next boundary', () {
      scheduler.sync(start, start);
      scheduler.onTick(start.add(const Duration(minutes: 29)));

      expect(notifications.scheduled, hasLength(1));
    });

    test('schedules the following boundary once the first is reached', () {
      scheduler.sync(start, start);
      scheduler.onTick(start.add(const Duration(minutes: 30)));

      expect(notifications.scheduled, hasLength(2));
      expect(
        notifications.scheduled.last.when,
        start.add(const Duration(minutes: 60)),
      );
    });

    test('does not schedule the same boundary twice on repeated ticks', () {
      scheduler.sync(start, start);
      scheduler.onTick(start.add(const Duration(minutes: 30)));
      scheduler.onTick(start.add(const Duration(minutes: 31)));
      scheduler.onTick(start.add(const Duration(minutes: 59)));

      expect(notifications.scheduled, hasLength(2));
    });

    test('restores the chain at the next boundary after app restart', () {
      // App was killed 45 minutes in; the 30-minute reminder was already
      // scheduled by the OS before the kill.
      scheduler.sync(start, start.add(const Duration(minutes: 45)));

      expect(notifications.scheduled, hasLength(1));
      expect(
        notifications.scheduled.single.when,
        start.add(const Duration(minutes: 60)),
      );
    });

    test('cancel stops reminders and clears tracking', () {
      scheduler.sync(start, start);
      scheduler.cancel();

      expect(notifications.cancelCount, 1);
      // A later tick must not resurrect reminders for a cancelled timer.
      scheduler.onTick(start.add(const Duration(minutes: 40)));
      expect(notifications.scheduled, hasLength(1));
    });

    test('does nothing while reminders are disabled', () {
      scheduler.configure(settings(enabled: false));
      scheduler.sync(start, start);

      expect(notifications.scheduled, isEmpty);
    });

    test('cancels a pending reminder when reminders are turned off mid-run',
        () {
      scheduler.sync(start, start);
      scheduler.configure(settings(enabled: false));

      expect(notifications.cancelCount, 1);
    });

    test('requests permission when reminders become enabled', () {
      // Fresh scheduler whose initial configure is also disabled, so no
      // permission request has happened yet.
      notifications = _RecordingNotificationService();
      scheduler = TimerReminderScheduler(notifications);
      scheduler.configure(settings(enabled: false));
      expect(notifications.permissionRequests, 0);

      scheduler.configure(settings(enabled: true));

      expect(notifications.permissionRequests, 1);
      // Repeated configure calls with the same state must not re-prompt.
      scheduler.configure(settings(enabled: true));
      expect(notifications.permissionRequests, 1);
    });

    test('reschedules with the new interval when the interval changes', () {
      scheduler.sync(start, start); // 30-minute boundary at 9:30 scheduled.
      now = start.add(const Duration(minutes: 10));
      scheduler.configure(settings(intervalMinutes: 60));

      // The 9:30 reminder stays queued; the next 60-minute boundary (10:00)
      // is scheduled right away since it is the nearest upcoming boundary.
      expect(notifications.scheduled, hasLength(2));
      expect(
        notifications.scheduled.last.when,
        start.add(const Duration(hours: 1)),
      );
      // No duplicate while the clock has not reached the boundary.
      now = start.add(const Duration(minutes: 59, seconds: 59));
      scheduler.onTick(now);
      expect(notifications.scheduled, hasLength(2));
      // The chain continues at 60-minute steps from the original start.
      now = start.add(const Duration(minutes: 60));
      scheduler.onTick(now);
      expect(notifications.scheduled, hasLength(3));
      expect(
        notifications.scheduled.last.when,
        start.add(const Duration(hours: 2)),
      );
    });

    test('ignores a non-positive interval', () {
      scheduler.configure(settings(intervalMinutes: 0));
      scheduler.sync(start, start);

      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelCount, 1);
    });

    test('fires reminders at start + n * interval for custom intervals', () {
      scheduler.configure(settings(intervalMinutes: 15));
      scheduler.sync(start, start);
      scheduler.onTick(start.add(const Duration(minutes: 15)));
      scheduler.onTick(start.add(const Duration(minutes: 16)));

      expect(notifications.scheduled, hasLength(2));
      expect(
        notifications.scheduled.map((r) => r.when),
        [start.add(const Duration(minutes: 15)), start.add(const Duration(minutes: 30))],
      );
    });
  });
}

class _RecordingNotificationService implements TimerNotificationService {
  final scheduled = <_ScheduledReminder>[];
  int cancelCount = 0;
  int permissionRequests = 0;

  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    scheduled.add(_ScheduledReminder(id: id, when: when, body: body));
  }
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.id,
    required this.when,
    required this.body,
  });

  final int id;
  final DateTime when;
  final String body;
}
