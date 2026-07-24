import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
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
}

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
