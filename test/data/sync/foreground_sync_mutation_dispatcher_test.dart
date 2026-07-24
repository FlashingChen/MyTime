import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/sync/foreground_sync_mutation_dispatcher.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
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
