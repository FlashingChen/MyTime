import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_service.dart';

void main() {
  final category = const Category(id: 'work', name: '工作', color: '#123456');

  SyncSnapshot snapshotAt(int hour) => SyncSnapshot(
    updatedAt: DateTime.utc(2026, 7, 12, hour),
    categories: [category],
    records: [
      TimeRecord(
        id: 'record-$hour',
        categoryId: category.id,
        startTime: DateTime.utc(2026, 7, 12, hour),
        endTime: DateTime.utc(2026, 7, 12, hour + 1),
        createdAt: DateTime.utc(2026, 7, 12, hour),
      ),
    ],
  );

  test(
    'applies a strictly newer remote snapshot without pushing it back',
    () async {
      final local = _FakeLocalStore(snapshotAt(9));
      final remote = _FakeSyncPort(remote: snapshotAt(10));
      final service = SyncService(local: local, remote: remote);

      final result = await service.synchronize();

      expect(result.resolution, SyncResolution.appliedRemote);
      expect(local.snapshot.updatedAt, DateTime.utc(2026, 7, 12, 10));
      expect(remote.pushed, isEmpty);
    },
  );

  test('pushes the local snapshot when it is newer than remote', () async {
    final local = _FakeLocalStore(snapshotAt(11));
    final remote = _FakeSyncPort(remote: snapshotAt(10));
    final service = SyncService(local: local, remote: remote);

    final result = await service.synchronize();

    expect(result.resolution, SyncResolution.pushedLocal);
    expect(remote.pushed.single.updatedAt, DateTime.utc(2026, 7, 12, 11));
    expect(local.replaceCalls, 0);
  });

  test('resolves equal timestamps in favor of the local snapshot', () async {
    final local = _FakeLocalStore(snapshotAt(10));
    final remote = _FakeSyncPort(remote: snapshotAt(10));
    final service = SyncService(local: local, remote: remote);

    final result = await service.synchronize();

    expect(result.resolution, SyncResolution.pushedLocal);
    expect(remote.pushed, hasLength(1));
    expect(local.replaceCalls, 0);
  });

  test('pushes a local snapshot when no remote document exists', () async {
    final local = _FakeLocalStore(snapshotAt(10));
    final remote = _FakeSyncPort();
    final service = SyncService(local: local, remote: remote);

    final result = await service.synchronize();

    expect(result.resolution, SyncResolution.pushedLocal);
    expect(remote.pushed, hasLength(1));
  });

  test(
    'does not overwrite a local mutation that occurs while pulling',
    () async {
      final local = _FakeLocalStore(snapshotAt(9));
      final pullStarted = Completer<void>();
      final releasePull = Completer<void>();
      final remote = _FakeSyncPort(
        remote: snapshotAt(10),
        onPull: () async {
          pullStarted.complete();
          await releasePull.future;
        },
      );
      final service = SyncService(local: local, remote: remote);

      final synchronization = service.synchronize();
      await pullStarted.future;
      local.snapshot = snapshotAt(11);
      releasePull.complete();

      final result = await synchronization;

      expect(result.resolution, SyncResolution.pushedLocal);
      expect(local.snapshot.updatedAt, DateTime.utc(2026, 7, 12, 11));
      expect(remote.pushed.single.updatedAt, DateTime.utc(2026, 7, 12, 11));
      expect(local.replaceCalls, 0);
    },
  );

  test(
    'rejects an invalid remote snapshot before changing local data',
    () async {
      final local = _FakeLocalStore(snapshotAt(9));
      final invalidRemote = SyncSnapshot(
        updatedAt: DateTime.utc(2026, 7, 12, 10),
        categories: [category],
        records: [
          TimeRecord(
            id: 'invalid',
            categoryId: category.id,
            startTime: DateTime.utc(2026, 7, 12, 10),
            endTime: DateTime.utc(2026, 7, 12, 9),
          ),
        ],
      );
      final remote = _FakeSyncPort(remote: invalidRemote);
      final service = SyncService(local: local, remote: remote);

      await expectLater(service.synchronize(), throwsArgumentError);

      expect(local.snapshot.updatedAt, DateTime.utc(2026, 7, 12, 9));
      expect(local.replaceCalls, 0);
      expect(remote.pushed, isEmpty);
    },
  );

  test('rejects a snapshot that would leave the application category-free', () {
    final empty = SyncSnapshot(
      updatedAt: DateTime.utc(2026, 7, 12),
      categories: const [],
      records: const [],
    );

    expect(empty.validate, throwsArgumentError);
  });
}

class _FakeLocalStore implements SyncLocalStore {
  _FakeLocalStore(this.snapshot);

  SyncSnapshot snapshot;
  int replaceCalls = 0;

  @override
  Future<SyncSnapshot> read() async => snapshot;

  @override
  Future<void> replace(SyncSnapshot value) async {
    replaceCalls++;
    snapshot = value;
  }

  @override
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot value,
  ) async {
    if (snapshot.updatedAt != expectedUpdatedAt) return false;
    await replace(value);
    return true;
  }
}

class _FakeSyncPort implements SyncPort {
  _FakeSyncPort({this.remote, this.onPull});

  final SyncSnapshot? remote;
  final Future<void> Function()? onPull;
  final List<SyncSnapshot> pushed = [];

  @override
  Future<SyncSnapshot?> pull() async {
    await onPull?.call();
    return remote;
  }

  @override
  Future<void> push(SyncSnapshot snapshot) async {
    pushed.add(snapshot);
  }
}
