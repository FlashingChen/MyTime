import 'package:mytime/data/sync/sync_revision_store.dart';

/// Marks a successful local data mutation for later synchronization.
abstract interface class SyncMutationMarker {
  /// Advances the local synchronization watermark.
  Future<void> markLocalChanged();
}

/// Advances a [SyncRevisionStore] monotonically after local data changes.
///
/// The resulting timestamp is always later than the previous value, including
/// when the device clock moves backwards or a remote device has a future clock.
class SyncMutationTracker implements SyncMutationMarker {
  SyncMutationTracker({
    required SyncRevisionStore revision,
    DateTime Function()? clock,
  }) : _revision = revision,
       _clock = clock ?? DateTime.now;

  final SyncRevisionStore _revision;
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

  Future<void> _advance() async {
    final current = (await _revision.readUpdatedAt()).toUtc();
    final now = _clock().toUtc();
    final next = now.isAfter(current)
        ? now
        : current.add(const Duration(microseconds: 1));
    await _revision.writeUpdatedAt(next);
  }
}
