import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_pending_state_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';
import 'package:mytime/data/sync/webdav_sync_coordinator.dart';
import 'package:mytime/main.dart';

void main() {
  test(
    'startup synchronizes remote additions through the foreground coordinator',
    () async {
      final local = _LocalStore(_snapshot('local'));
      final coordinator = WebDavSyncCoordinator(
        local: local,
        portFactory: (_) => _RemoteStore(_snapshot('remote')),
      );

      await synchronizeWebDavOnStartup(
        loadSettings: () async => const AppSettings(
          webDavEndpoint: 'https://dav.example.com/mytime.json',
          webDavUsername: 'alice',
          webDavPassword: 'secret',
        ),
        synchronize: coordinator.synchronize,
      );

      expect(
        local.snapshot.records.map((record) => record.id),
        contains('remote'),
      );
    },
  );

  test('startup recovery completes before automatic foreground sync', () async {
    final events = <String>[];

    await synchronizeWebDavOnStartup(
      recoverPendingImport: () async => events.add('recovery'),
      loadSettings: () async {
        events.add('settings');
        return const AppSettings(
          webDavEndpoint: 'https://dav.example.com/mytime.json',
          webDavUsername: 'alice',
          webDavPassword: 'secret',
        );
      },
      synchronize: (_) async => events.add('sync'),
    );

    expect(events, ['recovery', 'settings', 'sync']);
  });

  test(
    'startup failure retains pending revision and schedules a retry',
    () async {
      final pending = _MemoryPendingStore(DateTime.utc(2026, 7, 24, 12));
      final scheduler = _CountingScheduler();

      await expectLater(
        synchronizeWebDavOnStartup(
          loadSettings: () async => _settings,
          synchronize: (_) async => throw StateError('network failed'),
          pending: pending,
          scheduler: scheduler,
        ),
        throwsStateError,
      );

      expect(
        await pending.readPendingRevision(),
        DateTime.utc(2026, 7, 24, 12),
      );
      expect(scheduler.calls, 1);
    },
  );
}

const _settings = AppSettings(
  webDavEndpoint: 'https://dav.example.com/mytime.json',
  webDavUsername: 'alice',
  webDavPassword: 'secret',
);

SyncSnapshot _snapshot(String id) => SyncSnapshot(
  updatedAt: DateTime.utc(2026, 7, 24),
  categories: const [Category(id: 'work', name: '工作', color: '#123456')],
  records: [
    TimeRecord(
      id: id,
      categoryId: 'work',
      startTime: DateTime.utc(2026, 7, 24, 9),
      endTime: DateTime.utc(2026, 7, 24, 10),
    ),
  ],
);

class _LocalStore implements SyncLocalStore {
  _LocalStore(this.snapshot);

  SyncSnapshot snapshot;

  @override
  Future<T> runExclusive<T>(Future<T> Function() operation) => operation();

  @override
  Future<SyncSnapshot> read() async => snapshot;

  @override
  Future<SyncSnapshot> readReadOnly() async => snapshot;

  @override
  Future<void> replace(SyncSnapshot value) async => snapshot = value;

  @override
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot value,
  ) async {
    if (snapshot.updatedAt != expectedUpdatedAt) return false;
    snapshot = value;
    return true;
  }
}

class _RemoteStore implements SyncPort {
  _RemoteStore(this.snapshot);

  final SyncSnapshot snapshot;

  @override
  Future<RemoteSyncDocument?> pull() async =>
      RemoteSyncDocument(snapshot: snapshot, eTag: '"v1"');

  @override
  Future<String?> push(
    SyncSnapshot snapshot, {
    required String? ifMatch,
    required bool ifNoneMatch,
  }) async => '"v2"';

  @override
  Future<SyncLock?> lock() async => null;

  @override
  Future<void> unlock(SyncLock lock) async {}
}

class _MemoryPendingStore implements SyncPendingStateStore {
  _MemoryPendingStore(this.value);
  DateTime? value;
  @override
  Future<bool> clearIfMatches(DateTime revision) async {
    if (value != revision) return false;
    value = null;
    return true;
  }

  @override
  Future<void> markPending(DateTime revision) async => value = revision;
  @override
  Future<DateTime?> readPendingRevision() async => value;
}

class _CountingScheduler implements SyncScheduler {
  int calls = 0;
  @override
  Future<void> schedule() async => calls++;
}
