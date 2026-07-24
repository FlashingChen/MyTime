import 'dart:async';

import 'package:mytime/data/sync/foreground_sync_mutation_dispatcher.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';

/// Marks a successful local data mutation for later synchronization.
abstract interface class SyncMutationMarker {
  /// Advances the local synchronization watermark.
  Future<void> markLocalChanged();
}

/// Tracks the entity that changed so it can be merged independently.
abstract interface class SyncEntityMutationMarker extends SyncMutationMarker {
  Future<void> markChanged(SyncEntityKind kind, String id);
  Future<void> markDeleted(SyncEntityKind kind, String id);
}

/// Applies all entity mutations caused by an imported backup as one unit.
abstract interface class SyncImportMutationMarker
    implements SyncEntityMutationMarker {
  Future<void> markImportedChanges(
    List<SyncEntityChange> changes, {
    Future<void> Function()? refreshSnapshot,
    Future<void> Function()? beforeSchedule,
  });
}

/// One entity update or tombstone produced by a backup import.
class SyncEntityChange {
  const SyncEntityChange(this.kind, this.id, {required this.deleted});

  final SyncEntityKind kind;
  final String id;
  final bool deleted;
}

/// Advances a [SyncRevisionStore] monotonically after local data changes.
///
/// The resulting timestamp is always later than the previous value, including
/// when the device clock moves backwards or a remote device has a future clock.
class SyncMutationTracker implements SyncImportMutationMarker {
  SyncMutationTracker({
    required SyncRevisionStore revision,
    SyncMetadataStore? metadata,
    SyncScheduler? scheduler,
    ForegroundSyncMutationDispatcher? foregroundDispatcher,
    Future<void> Function()? refreshSnapshot,
    DateTime Function()? clock,
  }) : _revision = revision,
       _metadata = metadata,
       _scheduler = scheduler ?? const NoopSyncScheduler(),
       _foregroundDispatcher = foregroundDispatcher,
       _refreshSnapshot = refreshSnapshot,
       _clock = clock ?? DateTime.now;

  final SyncRevisionStore _revision;
  final SyncMetadataStore? _metadata;
  final SyncScheduler _scheduler;
  final ForegroundSyncMutationDispatcher? _foregroundDispatcher;
  final Future<void> Function()? _refreshSnapshot;
  final DateTime Function() _clock;
  Future<void> _pendingMutation = Future<void>.value();

  @override
  Future<void> markLocalChanged() {
    final mutation = _pendingMutation.then<void>((_) => _advance());
    _pendingMutation = mutation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return mutation;
  }

  @override
  Future<void> markChanged(SyncEntityKind kind, String id) =>
      _track(kind, id, deleted: false);

  @override
  Future<void> markDeleted(SyncEntityKind kind, String id) =>
      _track(kind, id, deleted: true);

  @override
  Future<void> markImportedChanges(
    List<SyncEntityChange> changes, {
    Future<void> Function()? refreshSnapshot,
    Future<void> Function()? beforeSchedule,
  }) {
    final mutation = _pendingMutation.then<void>((_) async {
      final previousRevision = await _revision.readUpdatedAt();
      final metadata = _metadata;
      final previousMetadata = await metadata?.read();
      try {
        await _advance();
        if (metadata != null) {
          var next = previousMetadata!;
          final now = _clock().toUtc();
          for (final change in changes) {
            next = _applyChange(next, change, now);
          }
          await metadata.write(next);
        }
        await (refreshSnapshot ?? _refreshSnapshot)?.call();
        await beforeSchedule?.call();
        _notifyCommittedMutation();
      } catch (error, stackTrace) {
        await _revision.writeUpdatedAt(previousRevision);
        if (metadata != null) await metadata.write(previousMetadata!);
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
    _pendingMutation = mutation.then<void>((_) {}, onError: (_, __) {});
    return mutation;
  }

  Future<void> _track(SyncEntityKind kind, String id, {required bool deleted}) {
    final mutation = _pendingMutation.then<void>((_) async {
      await _advance();
      final metadata = _metadata;
      if (metadata != null) {
        final now = _clock().toUtc();
        if (deleted) {
          await metadata.markDeleted(kind, id, now);
        } else {
          await metadata.markChanged(kind, id, now);
        }
      }
      await _refreshSnapshot?.call();
      _notifyCommittedMutation();
    });
    _pendingMutation = mutation.then<void>((_) {}, onError: (_, __) {});
    return mutation;
  }

  Future<void> _advance() async {
    final current = (await _revision.readUpdatedAt()).toUtc();
    final now = _clock().toUtc();
    final next = now.isAfter(current)
        ? now
        : current.add(const Duration(microseconds: 1));
    await _revision.writeUpdatedAt(next);
  }

  void _notifyCommittedMutation() {
    final dispatcher = _foregroundDispatcher;
    if (dispatcher != null) {
      dispatcher.mutationCommitted();
      return;
    }
    unawaited(_scheduleBackground());
  }

  Future<void> _scheduleBackground() async {
    try {
      await _scheduler.schedule();
    } catch (_) {
      // A durable entity revision remains pending for the next trigger.
    }
  }

  SyncMetadata _applyChange(
    SyncMetadata metadata,
    SyncEntityChange change,
    DateTime changedAt,
  ) {
    final values = Map<String, SyncEntityMetadata>.from(
      change.kind == SyncEntityKind.record
          ? metadata.records
          : metadata.categories,
    );
    final existing = values[change.id];
    values[change.id] = SyncEntityMetadata(
      kind: change.kind,
      id: change.id,
      updatedAt: change.deleted
          ? existing?.updatedAt
          : existing?.updatedAt?.isAfter(changedAt) ?? false
          ? existing!.updatedAt
          : changedAt,
      deletedAt: change.deleted
          ? existing?.deletedAt?.isAfter(changedAt) ?? false
                ? existing!.deletedAt
                : changedAt
          : null,
    );
    return change.kind == SyncEntityKind.record
        ? metadata.copyWith(records: values)
        : metadata.copyWith(categories: values);
  }
}
