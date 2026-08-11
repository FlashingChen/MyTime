import 'dart:async';

import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/services/timer_notification_service.dart';

/// Notification id used for the timer reminder. A fixed id means a newly
/// scheduled reminder replaces any still-pending one.
const timerReminderNotificationId = 1901;

/// Boundary between the timer and reminder scheduling.
///
/// Implemented by [TimerReminderScheduler]; the timer BLoC only depends on
/// this interface so tests can substitute a spy.
abstract interface class ReminderScheduler {
  /// Pushes fresh reminder configuration (called on settings load/save).
  void configure(AppSettings settings);

  /// Restarts scheduling for a timer that began at [startTime].
  void sync(DateTime startTime, DateTime now);

  /// Called on each timer tick; schedules the next boundary when reached.
  void onTick(DateTime now);

  /// Stops all reminders (timer stopped or reset).
  void cancel();
}

/// Schedules periodic "don't forget to stop the timer" reminders while a
/// timer is running.
///
/// Reminders fire at `startTime + n × interval` boundaries. Only the next
/// upcoming boundary is scheduled at a time; the app schedules the following
/// one on the next tick. When the app is killed, the OS still shows the last
/// scheduled reminder (and reschedules it after a reboot via the boot
/// receiver). Once the app is reopened, the ticker picks the chain back up.
class TimerReminderScheduler implements ReminderScheduler {
  TimerReminderScheduler(this._notifications, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TimerNotificationService _notifications;
  final DateTime Function() _clock;

  AppSettings _settings = const AppSettings();
  DateTime? _startTime;
  DateTime? _scheduledBoundary;

  @override
  void configure(AppSettings settings) {
    final wasEnabled = _settings.reminderEnabled;
    _settings = settings;
    if (settings.reminderEnabled && !wasEnabled) {
      unawaited(_notifications.requestPermission());
    }
    _sync();
  }

  @override
  void sync(DateTime startTime, DateTime now) {
    _startTime = startTime;
    _scheduledBoundary = null;
    _sync(now);
  }

  @override
  void onTick(DateTime now) => _sync(now);

  @override
  void cancel() {
    _startTime = null;
    _scheduledBoundary = null;
    unawaited(_notifications.cancelAll());
  }

  void _sync([DateTime? now]) {
    final start = _startTime;
    if (start == null) return;
    final intervalMinutes = _settings.reminderIntervalMinutes;
    if (!_settings.reminderEnabled || intervalMinutes <= 0) {
      // The user turned reminders off mid-run: drop the pending notification
      // but keep tracking the timer so it can be re-enabled later.
      _scheduledBoundary = null;
      unawaited(_notifications.cancelAll());
      return;
    }
    final current = now ?? _clock();
    final elapsed = current.difference(start);
    final nextIndex = elapsed.inMinutes ~/ intervalMinutes + 1;
    final nextBoundary = start.add(
      Duration(minutes: nextIndex * intervalMinutes),
    );
    final scheduled = _scheduledBoundary;
    if (scheduled != null && !nextBoundary.isAfter(scheduled)) {
      return; // The upcoming boundary is already scheduled.
    }
    _scheduledBoundary = nextBoundary;
    unawaited(
      _notifications.schedule(
        id: timerReminderNotificationId,
        when: nextBoundary,
        title: '计时提醒',
        body: '计时已进行 ${nextIndex * intervalMinutes} 分钟，别忘了停止计时。',
      ),
    );
  }
}

/// A scheduler that does nothing; used as the default so the timer BLoC
/// works standalone (e.g. in existing unit tests).
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  void configure(AppSettings settings) {}

  @override
  void sync(DateTime startTime, DateTime now) {}

  @override
  void onTick(DateTime now) {}

  @override
  void cancel() {}
}
