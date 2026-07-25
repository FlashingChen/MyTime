import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/preferences_sync_snapshot_store.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_service.dart';

void main() {
  final snapshot = SyncSnapshot(
    updatedAt: DateTime.utc(2026, 7, 24),
    categories: const [Category(id: 'work', name: '工作', color: '#123456')],
    records: [
      TimeRecord(
        id: 'record',
        categoryId: 'work',
        startTime: DateTime.utc(2026, 7, 24, 9),
        endTime: DateTime.utc(2026, 7, 24, 10),
        createdAt: DateTime.utc(2026, 7, 24, 9),
      ),
    ],
    metadata: SyncMetadata(
      eTag: '"v1"',
      records: {
        'record': SyncEntityMetadata(
          kind: SyncEntityKind.record,
          id: 'record',
          updatedAt: DateTime.utc(2026, 7, 24),
        ),
      },
      categories: {
        'deleted': SyncEntityMetadata(
          kind: SyncEntityKind.category,
          id: 'deleted',
          deletedAt: DateTime.utc(2026, 7, 23),
        ),
      },
    ),
  );

  test('persists and restores complete v2 snapshot metadata', () async {
    final store = PreferencesSyncSnapshotStore(_MemoryPreferences());

    await store.write(snapshot);

    expect(await store.readSnapshot(), snapshot);
  });

  test(
    'treats missing and malformed snapshots as no background work',
    () async {
      final preferences = _MemoryPreferences();
      final store = PreferencesSyncSnapshotStore(preferences);

      expect(await store.readSnapshot(), isNull);
      await preferences.setString(PreferencesSyncSnapshotStore.key, '{bad');
      expect(await store.readSnapshot(), isNull);
      expect(
        await preferences.getString(PreferencesSyncSnapshotStore.key),
        isNull,
      );
    },
  );

  test(
    'reconciles Hive payload while retaining persisted sync metadata',
    () async {
      final store = PreferencesSyncSnapshotStore(_MemoryPreferences());
      await store.write(snapshot);
      final foreground = SyncSnapshot(
        updatedAt: DateTime.utc(2026, 7, 25),
        categories: const [Category(id: 'home', name: '家庭', color: '#654321')],
        records: [],
      );

      final reconciled = await store.reconcileForeground(foreground);

      expect(reconciled.categories, foreground.categories);
      expect(reconciled.records, foreground.records);
      expect(reconciled.metadata, snapshot.metadata);
      expect(reconciled.metadata.eTag, '"v1"');
    },
  );

  test(
    'background sync cannot overwrite a newer foreground snapshot after reading',
    () async {
      final preferences = _MemoryPreferences();
      final store = PreferencesSyncSnapshotStore(preferences);
      await store.write(snapshot);
      final remote = _PausedRemote();

      final synchronization = SyncService(
        local: ReadOnlySyncLocalStore(store),
        remote: remote,
        applyMergedLocal: false,
      ).synchronize();
      await remote.pulled.future;

      final foreground = SyncSnapshot(
        updatedAt: DateTime.utc(2026, 7, 25),
        categories: snapshot.categories,
        records: const [],
        metadata: SyncMetadata(
          eTag: '"foreground"',
          records: {
            'record': SyncEntityMetadata(
              kind: SyncEntityKind.record,
              id: 'record',
              deletedAt: DateTime.utc(2026, 7, 25),
            ),
          },
          categories: {
            'deleted': SyncEntityMetadata(
              kind: SyncEntityKind.category,
              id: 'deleted',
              deletedAt: DateTime.utc(2026, 7, 25),
            ),
          },
        ),
      );
      await store.write(foreground);
      final persistedForeground =
          preferences.values[PreferencesSyncSnapshotStore.key]!;

      remote.allowPush.complete();
      await synchronization;

      expect(
        preferences.values[PreferencesSyncSnapshotStore.key],
        persistedForeground,
      );
      expect(await store.readSnapshot(), foreground);
      expect(preferences.writeCount, 2);
      expect(remote.pushCount, 1);

      await SyncService(local: store, remote: remote).synchronize();

      final foregroundSyncResult = await store.readSnapshot();
      expect(foregroundSyncResult!.records, isEmpty);
      expect(
        foregroundSyncResult.metadata.records['record']!.deletedAt,
        DateTime.utc(2026, 7, 25),
      );
    },
  );
}

class _PausedRemote implements SyncPort {
  final pulled = Completer<void>();
  final allowPush = Completer<void>();
  int pushCount = 0;
  SyncSnapshot? pushedSnapshot;

  @override
  Future<SyncLock?> lock() async => null;

  @override
  Future<RemoteSyncDocument?> pull() async {
    if (!pulled.isCompleted) {
      pulled.complete();
      await allowPush.future;
      return null;
    }
    return RemoteSyncDocument(snapshot: pushedSnapshot!, eTag: '"v2"');
  }

  @override
  Future<String?> push(
    SyncSnapshot snapshot, {
    required String? ifMatch,
    required bool ifNoneMatch,
  }) async {
    pushCount++;
    pushedSnapshot = snapshot;
    return '"v2"';
  }

  @override
  Future<void> unlock(SyncLock lock) async {}
}

class _MemoryPreferences implements PreferencesStore {
  final values = <String, String>{};
  int writeCount = 0;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setString(String key, String value) async {
    writeCount++;
    values[key] = value;
  }
}
