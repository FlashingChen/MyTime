import 'dart:io';

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

  test('retries when a PUT confirmation GET has another document', () async {
    final remote = _RemoteThatConfirmsDifferentDocument();

    await expectLater(
      SyncService(
        local: _Local(_snapshot('local')),
        remote: remote,
      ).synchronize(),
      throwsA(isA<SyncPreconditionFailed>()),
    );

    expect(remote.pullCount, 3);
    expect(remote.pushCount, 3);
  });

  test('unlocks a supported WebDAV lock after synchronization', () async {
    final remote = _Remote(_snapshot('remote'), lock: const SyncLock('token'));

    await SyncService(
      local: _Local(_snapshot('local')),
      remote: remote,
    ).synchronize();

    expect(remote.unlocked, ['token']);
  });

  test('keeps a successful synchronization when unlock fails', () async {
    final local = _Local(_snapshot('local'));
    final remote = _Remote(
      _snapshot('remote'),
      lock: const SyncLock('token'),
      unlockError: const HttpException('unlock failed'),
    );

    final result = await SyncService(
      local: local,
      remote: remote,
    ).synchronize();

    expect(result.resolution, SyncResolution.merged);
    expect(
      local.snapshot.records.map((record) => record.id),
      contains('remote'),
    );
  });

  test(
    'retries from the newest local snapshot when replacement sees a write',
    () async {
      final local = _Local(_snapshot('local'))
        ..advanceBeforeFirstReplace = true;
      final remote = _Remote(_snapshot('remote'));

      await SyncService(local: local, remote: remote).synchronize();

      expect(remote.pushed, hasLength(2));
      expect(
        remote.pushed.last.records.map((item) => item.id),
        contains('newer'),
      );
    },
  );

  test('rejects an existing remote document without an ETag', () async {
    final local = _Local(_snapshot('local'));
    final remote = _Remote(_snapshot('remote'), eTag: null);

    await expectLater(
      SyncService(local: local, remote: remote).synchronize(),
      throwsFormatException,
    );

    expect(remote.pushed, isEmpty);
  });

  test(
    'background synchronization does not replace the local snapshot',
    () async {
      final local = _Local(_snapshot('local'));
      final remote = _Remote(_snapshot('remote'));

      await SyncService(
        local: local,
        remote: remote,
        applyMergedLocal: false,
      ).synchronize();

      expect(local.snapshot.records.single.id, 'local');
      expect(
        remote.pushed.single.records.map((item) => item.id),
        contains('remote'),
      );
      expect(local.readOnlyCalls, 1);
      expect(local.readCalls, 0);
    },
  );
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
  bool advanceBeforeFirstReplace = false;
  int readCalls = 0;
  int readOnlyCalls = 0;
  @override
  Future<T> runExclusive<T>(Future<T> Function() operation) => operation();

  @override
  Future<SyncSnapshot> read() async {
    readCalls++;
    return snapshot;
  }

  @override
  Future<SyncSnapshot> readReadOnly() async {
    readOnlyCalls++;
    return snapshot;
  }

  @override
  Future<void> replace(SyncSnapshot value) async => snapshot = value;
  @override
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot value,
  ) async {
    if (advanceBeforeFirstReplace) {
      advanceBeforeFirstReplace = false;
      snapshot = _snapshot(
        'newer',
      ).copyWithUpdatedAt(DateTime.utc(2026, 7, 23));
    }
    if (snapshot.updatedAt != expectedUpdatedAt) {
      return false;
    }
    snapshot = value;
    return true;
  }
}

extension on SyncSnapshot {
  SyncSnapshot copyWithUpdatedAt(DateTime updatedAt) => SyncSnapshot(
    records: records,
    categories: categories,
    updatedAt: updatedAt,
    metadata: metadata,
  );
}

class _Remote implements SyncPort {
  _Remote(
    this.remote, {
    this.failures = 0,
    SyncLock? lock,
    this.eTag = '"v1"',
    this.unlockError,
  }) : _lock = lock;
  final SyncSnapshot remote;
  int failures;
  final SyncLock? _lock;
  final String? eTag;
  final Object? unlockError;
  int pullCount = 0;
  final List<SyncSnapshot> pushed = [];
  final List<String?> ifMatches = [];
  final List<String> unlocked = [];
  @override
  Future<RemoteSyncDocument?> pull() async {
    pullCount++;
    return RemoteSyncDocument(snapshot: remote, eTag: eTag);
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
  Future<void> unlock(SyncLock value) async {
    unlocked.add(value.token);
    if (unlockError != null) throw unlockError!;
  }
}

class _RemoteThatConfirmsDifferentDocument implements SyncPort {
  int pullCount = 0;
  int pushCount = 0;

  @override
  Future<RemoteSyncDocument?> pull() async {
    pullCount++;
    return null;
  }

  @override
  Future<String?> push(
    SyncSnapshot snapshot, {
    required String? ifMatch,
    required bool ifNoneMatch,
  }) async {
    pushCount++;
    throw const SyncPreconditionFailed();
  }

  @override
  Future<SyncLock?> lock() async => null;

  @override
  Future<void> unlock(SyncLock lock) async {}
}
