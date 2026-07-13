import 'package:mytime/data/providers/preferences_store.dart';

/// Persists the timestamp represented by the current local sync snapshot.
abstract interface class SyncRevisionStore {
  /// Reads the timestamp of the current local snapshot.
  Future<DateTime> readUpdatedAt();

  /// Replaces the timestamp of the current local snapshot.
  Future<void> writeUpdatedAt(DateTime updatedAt);
}

/// Stores the local sync revision in the application's preferences adapter.
///
/// A missing or malformed value intentionally means that the local dataset has
/// no known revision yet. Treating it as the Unix epoch lets the first sync
/// safely compare it with a remote document without failing application start.
class PreferencesSyncRevisionStore implements SyncRevisionStore {
  /// Preference key reserved for the version of the local sync snapshot.
  static const updatedAtKey = 'sync_snapshot_updated_at';

  PreferencesSyncRevisionStore(this._preferences);

  final PreferencesStore _preferences;

  @override
  Future<DateTime> readUpdatedAt() async {
    final stored = await _preferences.getString(updatedAtKey);
    if (stored == null) return _initialRevision;

    final parsed = DateTime.tryParse(stored);
    if (parsed == null) {
      await _preferences.remove(updatedAtKey);
      return _initialRevision;
    }
    return parsed.toUtc();
  }

  @override
  Future<void> writeUpdatedAt(DateTime updatedAt) {
    return _preferences.setString(
      updatedAtKey,
      updatedAt.toUtc().toIso8601String(),
    );
  }

  static final DateTime _initialRevision = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );
}
