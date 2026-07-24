import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/sync/foreground_sync_mutation_dispatcher.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_pending_state_store.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';

void main() {
  test(
    'dispatches a committed foreground mutation through synchronization instead of WorkManager',
    () async {
      final foregroundSyncStarted = Completer<void>();
      final scheduler = _CountingScheduler();
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async => true,
        synchronize: () async => foregroundSyncStarted.complete(),
        scheduler: scheduler,
      );
      final tracker = SyncMutationTracker(
        revision: _MemoryRevisionStore(DateTime.utc(2026, 7, 1)),
        metadata: _MemoryMetadataStore(const SyncMetadata()),
        foregroundDispatcher: dispatcher,
        clock: () => DateTime.utc(2026, 7, 2),
      );

      await tracker.markChanged(SyncEntityKind.record, 'record');
      await foregroundSyncStarted.future;

      expect(scheduler.calls, 0);
    },
  );

  test(
    'retains pending work and schedules after an active sync failure',
    () async {
      final pending = _MemoryPendingStore(DateTime.utc(2026, 7, 24, 12));
      final scheduler = _CountingScheduler();
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async => true,
        synchronize: () async => throw StateError('network failed'),
        scheduler: scheduler,
        pending: pending,
      );

      dispatcher.mutationCommitted();
      await _waitFor(() => scheduler.calls == 1);

      expect(
        await pending.readPendingRevision(),
        DateTime.utc(2026, 7, 24, 12),
      );
    },
  );

  test(
    'does not clear a new pending revision after an earlier sync succeeds',
    () async {
      final firstStarted = Completer<void>();
      final finishFirst = Completer<void>();
      var syncCalls = 0;
      final pending = _MemoryPendingStore(DateTime.utc(2026, 7, 24, 12));
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async => true,
        synchronize: () async {
          syncCalls++;
          if (syncCalls == 1) {
            firstStarted.complete();
            await finishFirst.future;
          }
        },
        scheduler: _CountingScheduler(),
        pending: pending,
      );

      dispatcher.mutationCommitted();
      await firstStarted.future;
      await pending.markPending(DateTime.utc(2026, 7, 24, 13));
      dispatcher.mutationCommitted();
      finishFirst.complete();
      await _waitFor(
        () => pending.clearAttempts.contains(DateTime.utc(2026, 7, 24, 13)),
      );

      expect(await pending.readPendingRevision(), isNull);
    },
  );

  test(
    'hands off durable pending work after dispatcher reconstruction',
    () async {
      final scheduler = _CountingScheduler();
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async => false,
        synchronize: () async {},
        scheduler: scheduler,
        pending: _MemoryPendingStore(DateTime.utc(2026, 7, 24, 12)),
      );

      dispatcher.foregroundBecameInactive();
      await _waitFor(() => scheduler.calls == 1);
    },
  );

  test(
    'coalesces rapid foreground mutations into one follow-up sync',
    () async {
      final firstSyncStarted = Completer<void>();
      final allowFirstSync = Completer<void>();
      final secondSyncStarted = Completer<void>();
      var syncCalls = 0;
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async => true,
        synchronize: () async {
          syncCalls++;
          if (syncCalls == 1) {
            firstSyncStarted.complete();
            await allowFirstSync.future;
          } else {
            secondSyncStarted.complete();
          }
        },
        scheduler: _CountingScheduler(),
      );

      dispatcher.mutationCommitted();
      await firstSyncStarted.future;
      dispatcher.mutationCommitted();
      dispatcher.mutationCommitted();
      allowFirstSync.complete();
      await secondSyncStarted.future;

      expect(syncCalls, 2);
    },
  );

  test(
    'coalesces mutations committed before foreground ownership resolves',
    () async {
      final ownershipResolved = Completer<void>();
      final firstSyncStarted = Completer<void>();
      final allowFirstSync = Completer<void>();
      final secondSyncStarted = Completer<void>();
      var syncCalls = 0;
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async {
          await ownershipResolved.future;
          return true;
        },
        synchronize: () async {
          syncCalls++;
          if (syncCalls == 1) {
            firstSyncStarted.complete();
            await allowFirstSync.future;
          } else {
            secondSyncStarted.complete();
          }
        },
        scheduler: _CountingScheduler(),
      );

      dispatcher.mutationCommitted();
      dispatcher.mutationCommitted();
      dispatcher.mutationCommitted();
      ownershipResolved.complete();
      await firstSyncStarted.future;
      allowFirstSync.complete();
      await secondSyncStarted.future;

      expect(syncCalls, 2);
    },
  );

  test(
    'releases dispatching after inactive admission so a later active mutation synchronizes',
    () async {
      final scheduler = _CountingScheduler();
      final synchronized = Completer<void>();
      var foregroundActive = false;
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async => foregroundActive,
        synchronize: () async => synchronized.complete(),
        scheduler: scheduler,
      );

      dispatcher.mutationCommitted();
      await _waitFor(() => scheduler.calls == 1);
      foregroundActive = true;
      dispatcher.mutationCommitted();

      await synchronized.future;
      expect(scheduler.calls, 1);
    },
  );

  test(
    'releases dispatching after an ownership check error so a later active mutation synchronizes',
    () async {
      final synchronized = Completer<void>();
      var throwsOwnershipError = true;
      final dispatcher = ForegroundSyncMutationDispatcher(
        foregroundIsActive: () async {
          if (throwsOwnershipError) throw StateError('ownership unavailable');
          return true;
        },
        synchronize: () async => synchronized.complete(),
        scheduler: _CountingScheduler(),
      );

      dispatcher.mutationCommitted();
      await Future<void>.delayed(Duration.zero);
      throwsOwnershipError = false;
      dispatcher.mutationCommitted();

      await synchronized.future;
    },
  );
}

Future<void> _waitFor(bool Function() condition) async {
  while (!condition()) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _MemoryRevisionStore implements SyncRevisionStore {
  _MemoryRevisionStore(this.value);

  DateTime value;

  @override
  Future<DateTime> readUpdatedAt() async => value;

  @override
  Future<void> writeUpdatedAt(DateTime updatedAt) async => value = updatedAt;
}

class _MemoryMetadataStore implements SyncMetadataStore {
  _MemoryMetadataStore(this.value);

  SyncMetadata value;

  @override
  Future<void> markChanged(
    SyncEntityKind kind,
    String id,
    DateTime changedAt,
  ) async {}

  @override
  Future<void> markDeleted(
    SyncEntityKind kind,
    String id,
    DateTime deletedAt,
  ) async {}

  @override
  Future<SyncMetadata> read() async => value;

  @override
  Future<void> write(SyncMetadata metadata) async => value = metadata;
}

class _CountingScheduler implements SyncScheduler {
  int calls = 0;

  @override
  Future<void> schedule() async => calls++;
}

class _MemoryPendingStore implements SyncPendingStateStore {
  _MemoryPendingStore(this.value);

  DateTime? value;
  final clearAttempts = <DateTime>[];

  @override
  Future<bool> clearIfMatches(DateTime revision) async {
    clearAttempts.add(revision);
    if (value != revision) return false;
    value = null;
    return true;
  }

  @override
  Future<void> markPending(DateTime revision) async {
    if (value == null || revision.isAfter(value!)) value = revision;
  }

  @override
  Future<DateTime?> readPendingRevision() async => value;
}
