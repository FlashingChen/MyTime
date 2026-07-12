import 'package:mytime/data/providers/preferences_store.dart';

/// A running timer or a stopped timer awaiting record confirmation.
class PersistedTimerSession {
  final DateTime startTime;
  final DateTime? stoppedAt;

  const PersistedTimerSession({required this.startTime, this.stoppedAt});

  bool get isPendingConfirmation => stoppedAt != null;
}

/// Storage boundary for the start time of an active timer session.
abstract interface class ActiveTimerStore {
  /// Saves the complete timer session, including its fixed stop time if any.
  Future<void> saveSession(PersistedTimerSession session);

  /// Returns the currently persisted timer session, if any.
  Future<PersistedTimerSession?> getSession();

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
  static const _keyStoppedAt = 'active_timer_stopped_at';

  ActiveTimerRepository({PreferencesStore? preferences})
    : _preferences = preferences ?? SharedPreferencesStore();

  final PreferencesStore _preferences;

  /// Saves the start timestamp of the currently running timer.
  @override
  Future<void> saveStartTime(DateTime startTime) async {
    await saveSession(PersistedTimerSession(startTime: startTime));
  }

  /// Returns the persisted start timestamp, or `null` if no active timer exists.
  @override
  Future<DateTime?> getStartTime() async {
    return (await getSession())?.startTime;
  }

  @override
  Future<void> saveSession(PersistedTimerSession session) async {
    await _preferences.setString(
      _keyStartTime,
      session.startTime.toIso8601String(),
    );
    if (session.stoppedAt == null) {
      await _preferences.remove(_keyStoppedAt);
    } else {
      await _preferences.setString(
        _keyStoppedAt,
        session.stoppedAt!.toIso8601String(),
      );
    }
  }

  @override
  Future<PersistedTimerSession?> getSession() async {
    final startIso = await _preferences.getString(_keyStartTime);
    if (startIso == null) return null;
    final stoppedIso = await _preferences.getString(_keyStoppedAt);
    return PersistedTimerSession(
      startTime: DateTime.parse(startIso),
      stoppedAt: stoppedIso == null ? null : DateTime.parse(stoppedIso),
    );
  }

  /// Clears any persisted active timer.
  @override
  Future<void> clear() async {
    await _preferences.remove(_keyStartTime);
    await _preferences.remove(_keyStoppedAt);
  }
}
