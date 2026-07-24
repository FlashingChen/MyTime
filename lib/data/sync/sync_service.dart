import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_merge_service.dart';

/// The direction selected by one synchronization attempt.
enum SyncResolution { merged }

/// Immutable outcome of a successful synchronization attempt.
class SyncResult {
  const SyncResult(this.resolution, {this.retryCount = 0});

  final SyncResolution resolution;
  final int retryCount;
}

/// Coordinates one remote target and one local snapshot store.
///
/// Conflicts use whole-snapshot last-write-wins semantics: the strictly newer
/// `updatedAt` wins. Equal timestamps intentionally prefer local data, making
/// the outcome deterministic and avoiding a destructive remote overwrite.
class SyncService {
  SyncService({
    required SyncLocalStore local,
    required SyncPort remote,
    SyncMergeService? merger,
    this.applyMergedLocal = true,
  }) : _local = local,
       _remote = remote,
       _merger = merger ?? SyncMergeService();

  final SyncLocalStore _local;
  final SyncPort _remote;
  final SyncMergeService _merger;
  final bool applyMergedLocal;
  Future<SyncResult>? _inFlight;

  /// Performs one pull/compare/apply-or-push cycle.
  ///
  /// Calls made while a cycle is active share that same cycle, so two callers
  /// cannot apply different remote snapshots concurrently.
  Future<SyncResult> synchronize() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final started = _synchronize();
    _inFlight = started;
    started.then<void>(
      (_) => _clearInFlight(started),
      onError: (Object _, StackTrace __) => _clearInFlight(started),
    );
    return started;
  }

  Future<SyncResult> _synchronize() async {
    return _local.runExclusive(_synchronizeExclusive);
  }

  Future<SyncResult> _synchronizeExclusive() async {
    SyncLock? lock;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final local = await (applyMergedLocal
            ? _local.read()
            : _local.readReadOnly());
        local.validate();
        final remote = await _remote.pull();
        if (remote != null && remote.eTag == null) {
          throw const FormatException(
            'WebDAV GET response did not include ETag',
          );
        }
        if (remote != null) lock ??= await _remote.lock();
        final merged = remote == null
            ? local
            : _merger.merge(local: local, remote: remote.snapshot);
        try {
          final eTag = await _remote.push(
            merged,
            ifMatch: remote?.eTag,
            ifNoneMatch: remote == null,
          );
          if (applyMergedLocal) {
            final applied = await _local.replaceIfCurrent(
              local.updatedAt,
              SyncSnapshot(
                records: merged.records,
                categories: merged.categories,
                updatedAt: merged.updatedAt,
                metadata: merged.metadata.copyWith(
                  eTag: eTag ?? remote?.eTag,
                  lastSuccessAt: DateTime.now().toUtc(),
                ),
              ),
            );
            if (!applied) {
              continue;
            }
          }
        } on SyncPreconditionFailed {
          if (attempt == 2) rethrow;
          continue;
        }
        return SyncResult(SyncResolution.merged, retryCount: attempt);
      }
    } finally {
      if (lock != null) {
        try {
          await _remote.unlock(lock);
        } catch (_) {
          // Cleanup must not replace the transaction outcome.
        }
      }
    }
    throw StateError('unreachable');
  }

  void _clearInFlight(Future<SyncResult> completed) {
    if (identical(_inFlight, completed)) _inFlight = null;
  }
}
