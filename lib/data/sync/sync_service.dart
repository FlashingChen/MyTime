import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';

/// The direction selected by one synchronization attempt.
enum SyncResolution { appliedRemote, pushedLocal }

/// Immutable outcome of a successful synchronization attempt.
class SyncResult {
  const SyncResult(this.resolution);

  final SyncResolution resolution;
}

/// Coordinates one remote target and one local snapshot store.
///
/// Conflicts use whole-snapshot last-write-wins semantics: the strictly newer
/// `updatedAt` wins. Equal timestamps intentionally prefer local data, making
/// the outcome deterministic and avoiding a destructive remote overwrite.
class SyncService {
  SyncService({required SyncLocalStore local, required SyncPort remote})
    : _local = local,
      _remote = remote;

  final SyncLocalStore _local;
  final SyncPort _remote;
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
    final local = await _local.read();
    local.validate();

    final remote = await _remote.pull();
    if (remote == null) {
      await _remote.push(await _currentLocal());
      return const SyncResult(SyncResolution.pushedLocal);
    }

    remote.validate();
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      final applied = await _local.replaceIfCurrent(local.updatedAt, remote);
      if (applied) return const SyncResult(SyncResolution.appliedRemote);
    }

    await _remote.push(await _currentLocal());
    return const SyncResult(SyncResolution.pushedLocal);
  }

  Future<SyncSnapshot> _currentLocal() async {
    final snapshot = await _local.read();
    snapshot.validate();
    return snapshot;
  }

  void _clearInFlight(Future<SyncResult> completed) {
    if (identical(_inFlight, completed)) _inFlight = null;
  }
}
