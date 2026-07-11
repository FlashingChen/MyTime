import 'package:shared_preferences/shared_preferences.dart';

/// Storage boundary for the start time of an active timer session.
abstract interface class ActiveTimerStore {
  /// Saves the start timestamp of the currently running timer.
  Future<void> saveStartTime(DateTime startTime);

  /// Returns the persisted start timestamp, or `null` if no session exists.
  Future<DateTime?> getStartTime();

  /// Clears any persisted active timer.
  Future<void> clear();
}

/// Repository for persisting the active (in-progress) timer session.
///
/// Stores the timer's start timestamp to SharedPreferences so that the
/// timer can be restored after the app is killed and relaunched.
class ActiveTimerRepository implements ActiveTimerStore {
  static const _keyStartTime = 'active_timer_start_time';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  /// Saves the start timestamp of the currently running timer.
  @override
  Future<void> saveStartTime(DateTime startTime) async {
    final prefs = await _prefs;
    await prefs.setString(_keyStartTime, startTime.toIso8601String());
  }

  /// Returns the persisted start timestamp, or `null` if no active timer exists.
  @override
  Future<DateTime?> getStartTime() async {
    final prefs = await _prefs;
    final iso = prefs.getString(_keyStartTime);
    if (iso == null) return null;
    return DateTime.parse(iso);
  }

  /// Clears any persisted active timer.
  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_keyStartTime);
  }
}
