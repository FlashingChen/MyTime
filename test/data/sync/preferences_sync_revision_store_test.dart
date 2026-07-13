import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';

void main() {
  test('uses the Unix epoch until a revision has been persisted', () async {
    final preferences = _MemoryPreferencesStore();
    final store = PreferencesSyncRevisionStore(preferences);

    expect(
      await store.readUpdatedAt(),
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  });

  test('persists revisions as normalized UTC timestamps', () async {
    final preferences = _MemoryPreferencesStore();
    final store = PreferencesSyncRevisionStore(preferences);
    final localTime = DateTime(2026, 7, 12, 20, 30, 15, 123, 456);

    await store.writeUpdatedAt(localTime);

    expect(
      preferences.values[PreferencesSyncRevisionStore.updatedAtKey],
      localTime.toUtc().toIso8601String(),
    );
    expect(await store.readUpdatedAt(), localTime.toUtc());
  });

  test('clears an unreadable persisted revision instead of throwing', () async {
    final preferences = _MemoryPreferencesStore({
      PreferencesSyncRevisionStore.updatedAtKey: 'not-a-timestamp',
    });
    final store = PreferencesSyncRevisionStore(preferences);

    expect(
      await store.readUpdatedAt(),
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    expect(
      preferences.values.containsKey(PreferencesSyncRevisionStore.updatedAtKey),
      isFalse,
    );
  });

  test(
    'advances beyond a future revision when the local clock is behind',
    () async {
      final revision = _MemoryRevisionStore(DateTime.utc(2030, 1, 1));
      final tracker = SyncMutationTracker(
        revision: revision,
        clock: () => DateTime.utc(2026, 7, 12),
      );

      await tracker.markLocalChanged();

      expect(
        revision.value,
        DateTime.utc(2030, 1, 1).add(const Duration(microseconds: 1)),
      );
    },
  );

  test(
    'serializes concurrent local mutations without reusing a revision',
    () async {
      final initial = DateTime.utc(2030, 1, 1);
      final revision = _MemoryRevisionStore(initial);
      final tracker = SyncMutationTracker(
        revision: revision,
        clock: () => DateTime.utc(2026, 7, 12),
      );

      await Future.wait([
        tracker.markLocalChanged(),
        tracker.markLocalChanged(),
      ]);

      expect(revision.value, initial.add(const Duration(microseconds: 2)));
    },
  );
}

class _MemoryPreferencesStore implements PreferencesStore {
  _MemoryPreferencesStore([Map<String, String>? initial])
    : values = Map<String, String>.from(initial ?? const {});

  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _MemoryRevisionStore implements SyncRevisionStore {
  _MemoryRevisionStore(this.value);

  DateTime value;

  @override
  Future<DateTime> readUpdatedAt() async => value;

  @override
  Future<void> writeUpdatedAt(DateTime updatedAt) async {
    value = updatedAt;
  }
}
