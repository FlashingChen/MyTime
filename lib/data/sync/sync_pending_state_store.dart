import 'package:mytime/data/providers/preferences_store.dart';

/// Persists the newest published local revision that still needs synchronization.
abstract interface class SyncPendingStateStore {
  Future<DateTime?> readPendingRevision();

  Future<void> markPending(DateTime revision);

  Future<bool> clearIfMatches(DateTime revision);
}

/// Stores durable WebDAV synchronization responsibility in preferences.
class PreferencesSyncPendingStateStore implements SyncPendingStateStore {
  static const key = 'webdav.sync.pending_revision';

  PreferencesSyncPendingStateStore(this._preferences);

  final PreferencesStore _preferences;

  @override
  Future<DateTime?> readPendingRevision() async {
    final value = await _preferences.getString(key);
    if (value == null) return null;
    final revision = DateTime.tryParse(value);
    if (revision == null) {
      await _preferences.remove(key);
      return null;
    }
    return revision.toUtc();
  }

  @override
  Future<void> markPending(DateTime revision) async {
    final next = revision.toUtc();
    final current = await readPendingRevision();
    if (current != null && !next.isAfter(current)) return;
    await _preferences.setString(key, next.toIso8601String());
  }

  @override
  Future<bool> clearIfMatches(DateTime revision) async {
    final current = await readPendingRevision();
    if (current != revision.toUtc()) return false;
    await _preferences.remove(key);
    return true;
  }
}

/// Used only where synchronization responsibility is intentionally unavailable.
class NoopSyncPendingStateStore implements SyncPendingStateStore {
  const NoopSyncPendingStateStore();

  @override
  Future<bool> clearIfMatches(DateTime revision) async => false;

  @override
  Future<void> markPending(DateTime revision) async {}

  @override
  Future<DateTime?> readPendingRevision() async => null;
}
