import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_service.dart';
import 'package:mytime/data/sync/webdav_sync_coordinator.dart';

void main() {
  test('builds a WebDAV sync attempt from the saved configuration', () async {
    final local = _LocalStore(_snapshot());
    late WebDavConfiguration captured;
    final remote = _RemoteStore();
    final coordinator = WebDavSyncCoordinator(
      local: local,
      portFactory: (configuration) {
        captured = configuration;
        return remote;
      },
    );

    final result = await coordinator.synchronize(
      const WebDavConfiguration(
        endpoint: 'https://dav.example.com/mytime.json',
        username: 'alice',
        password: 'secret',
      ),
    );

    expect(captured.endpoint, 'https://dav.example.com/mytime.json');
    expect(captured.username, 'alice');
    expect(remote.pushed, hasLength(1));
    expect(result.resolution, SyncResolution.merged);
  });

  test('reuses the in-flight sync only for the same configuration', () async {
    final local = _LocalStore(_snapshot());
    final endpoints = <String>[];
    final coordinator = WebDavSyncCoordinator(
      local: local,
      portFactory: (configuration) {
        endpoints.add(configuration.endpoint);
        return _RemoteStore();
      },
    );
    const first = WebDavConfiguration(
      endpoint: 'https://dav.example.com/mytime.json',
      username: 'alice',
      password: 'secret',
    );
    const same = WebDavConfiguration(
      endpoint: 'https://dav.example.com/mytime.json',
      username: 'alice',
      password: 'other-password',
    );
    const changed = WebDavConfiguration(
      endpoint: 'https://other.example.com/mytime.json',
      username: 'alice',
      password: 'secret',
    );

    final attempt = coordinator.synchronize(first);
    // Same endpoint + username: share the in-flight attempt even with a
    // different password.
    expect(identical(coordinator.synchronize(same), attempt), isTrue);
    // Changed endpoint: the stale in-flight attempt must not be returned.
    final fresh = coordinator.synchronize(changed);
    expect(identical(fresh, attempt), isFalse);

    await Future.wait([attempt, fresh]);
    expect(endpoints, [
      'https://dav.example.com/mytime.json',
      'https://other.example.com/mytime.json',
    ]);
  });
}

SyncSnapshot _snapshot() => SyncSnapshot(
  updatedAt: DateTime.utc(2026, 7, 12),
  categories: [const Category(id: 'work', name: '工作', color: '#123456')],
  records: [
    TimeRecord(
      id: 'record',
      categoryId: 'work',
      startTime: DateTime.utc(2026, 7, 12, 9),
      endTime: DateTime.utc(2026, 7, 12, 10),
    ),
  ],
);

class _LocalStore implements SyncLocalStore {
  _LocalStore(this.snapshot);

  final SyncSnapshot snapshot;

  @override
  Future<T> runExclusive<T>(Future<T> Function() operation) => operation();

  @override
  Future<SyncSnapshot> read() async => snapshot;

  @override
  Future<SyncSnapshot> readReadOnly() async => snapshot;

  @override
  Future<void> replace(SyncSnapshot snapshot) async {}

  @override
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot value,
  ) async => snapshot.updatedAt == expectedUpdatedAt;
}

class _RemoteStore implements SyncPort {
  final List<SyncSnapshot> pushed = [];

  @override
  Future<RemoteSyncDocument?> pull() async => null;

  @override
  Future<String?> push(
    SyncSnapshot snapshot, {
    required String? ifMatch,
    required bool ifNoneMatch,
  }) async {
    pushed.add(snapshot);
    return '"etag"';
  }

  @override
  Future<SyncLock?> lock() async => null;

  @override
  Future<void> unlock(SyncLock lock) async {}
}
