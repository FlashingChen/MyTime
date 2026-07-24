import 'package:mytime/data/providers/preferences_store.dart';

/// Stores the short-lived heartbeat that identifies the foreground sync owner.
class ForegroundSyncOwnership {
  ForegroundSyncOwnership({
    required PreferencesStore preferences,
    DateTime Function()? clock,
  }) : _preferences = preferences,
       _clock = clock ?? DateTime.now;

  static const heartbeatKey = 'webdav.foreground.heartbeat';
  static const refreshInterval = Duration(seconds: 30);
  static const activeWindow = Duration(seconds: 90);

  final PreferencesStore _preferences;
  final DateTime Function() _clock;

  Future<void> activate() => refresh();

  Future<void> refresh() =>
      _preferences.setString(heartbeatKey, _clock().toUtc().toIso8601String());

  Future<void> deactivate() => _preferences.remove(heartbeatKey);

  Future<bool> isForegroundActive() async {
    final value = await _preferences.getString(heartbeatKey);
    final heartbeat = value == null ? null : DateTime.tryParse(value)?.toUtc();
    final now = _clock().toUtc();
    return heartbeat != null &&
        !heartbeat.isAfter(now) &&
        now.difference(heartbeat) <= activeWindow;
  }
}
