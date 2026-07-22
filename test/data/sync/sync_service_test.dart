import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_service.dart';

void main() {
  test('merges unrelated records and writes with the remote ETag', () async {
    final local = _Local(_snapshot('local'));
    final remote = _Remote(_snapshot('remote'));

    final result = await SyncService(
      local: local,
      remote: remote,
    ).synchronize();

    expect(result.resolution, SyncResolution.merged);
    expect(
      remote.pushed.single.records.map((item) => item.id),
      containsAll(['local', 'remote']),
    );
    expect(remote.ifMatches, ['"v1"']);
  });

  test('re-pulls and retries after a precondition failure', () async {
    final local = _Local(_snapshot('local'));
    final remote = _Remote(_snapshot('remote'), failures: 1);

    final result = await SyncService(
      local: local,
      remote: remote,
    ).synchronize();

    expect(result.retryCount, 1);
    expect(remote.pullCount, 2);
    expect(remote.pushed, hasLength(2));
  });

  test('unlocks a supported WebDAV lock after synchronization', () async {
    final remote = _Remote(_snapshot('remote'), lock: const SyncLock('token'));

    await SyncService(
      local: _Local(_snapshot('local')),
      remote: remote,
    ).synchronize();

    expect(remote.unlocked, ['token']);
  });
}

SyncSnapshot _snapshot(String id) => SyncSnapshot(
  updatedAt: DateTime.utc(2026, 7, 22),
  categories: const [Category(id: 'work', name: '工作', color: '#123456')],
  records: [
    TimeRecord(
      id: id,
      categoryId: 'work',
      startTime: DateTime.utc(2026, 7, 22, 9),
      endTime: DateTime.utc(2026, 7, 22, 10),
    ),
  ],
);

class _Local implements SyncLocalStore {
  _Local(this.snapshot);
  SyncSnapshot snapshot;
  @override
  Future<SyncSnapshot> read() async => snapshot;
  @override
  Future<void> replace(SyncSnapshot value) async => snapshot = value;
  @override
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot value,
  ) async {
    if (snapshot.updatedAt != expectedUpdatedAt) {
      return false;
    }
    snapshot = value;
    return true;
  }
}

class _Remote implements SyncPort {
  _Remote(this.remote, {this.failures = 0, SyncLock? lock}) : _lock = lock;
  final SyncSnapshot remote;
  int failures;
  final SyncLock? _lock;
  int pullCount = 0;
  final List<SyncSnapshot> pushed = [];
  final List<String?> ifMatches = [];
  final List<String> unlocked = [];
  @override
  Future<RemoteSyncDocument?> pull() async {
    pullCount++;
    return RemoteSyncDocument(snapshot: remote, eTag: '"v1"');
  }

  @override
  Future<String?> push(
    SyncSnapshot snapshot, {
    required String? ifMatch,
    required bool ifNoneMatch,
  }) async {
    pushed.add(snapshot);
    ifMatches.add(ifMatch);
    if (failures-- > 0) throw const SyncPreconditionFailed();
    return '"v2"';
  }

  @override
  Future<SyncLock?> lock() async => _lock;
  @override
  Future<void> unlock(SyncLock value) async => unlocked.add(value.token);
}
