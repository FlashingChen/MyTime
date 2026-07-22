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

/// Advances a [SyncRevisionStore] monotonically after local data changes.
///
/// The resulting timestamp is always later than the previous value, including
/// when the device clock moves backwards or a remote device has a future clock.
class SyncMutationTracker implements SyncEntityMutationMarker {
  SyncMutationTracker({
    required SyncRevisionStore revision,
    SyncMetadataStore? metadata,
    SyncScheduler? scheduler,
    DateTime Function()? clock,
  }) : _revision = revision,
       _metadata = metadata,
       _scheduler = scheduler ?? const NoopSyncScheduler(),
       _clock = clock ?? DateTime.now;

  final SyncRevisionStore _revision;
  final SyncMetadataStore? _metadata;
  final SyncScheduler _scheduler;
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
      try {
        await _scheduler.schedule();
      } catch (_) {
        // A durable entity revision remains pending for the next trigger.
      }
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
}
