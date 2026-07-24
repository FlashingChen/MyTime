import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/sync_pending_state_store.dart';

void main() {
  test('reads malformed pending revision as clean and removes it', () async {
    final preferences = _MemoryPreferences()
      ..values[PreferencesSyncPendingStateStore.key] = 'not-a-time';
    final store = PreferencesSyncPendingStateStore(preferences);

    expect(await store.readPendingRevision(), isNull);
    expect(preferences.values, isEmpty);
  });

  test('only advances the pending revision', () async {
    final preferences = _MemoryPreferences();
    final store = PreferencesSyncPendingStateStore(preferences);
    final newer = DateTime.utc(2026, 7, 24, 12);

    await store.markPending(newer);
    await store.markPending(DateTime.utc(2026, 7, 24, 11));

    expect(await store.readPendingRevision(), newer);
  });

  test('clears only the matching pending revision', () async {
    final preferences = _MemoryPreferences();
    final store = PreferencesSyncPendingStateStore(preferences);
    final pending = DateTime.utc(2026, 7, 24, 12);
    await store.markPending(pending);

    expect(await store.clearIfMatches(DateTime.utc(2026, 7, 24, 11)), isFalse);
    expect(await store.readPendingRevision(), pending);
    expect(await store.clearIfMatches(pending), isTrue);
    expect(await store.readPendingRevision(), isNull);
  });
}

class _MemoryPreferences implements PreferencesStore {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
