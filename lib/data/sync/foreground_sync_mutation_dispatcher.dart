import 'dart:async';

import 'package:mytime/data/sync/sync_scheduler.dart';
import 'package:mytime/data/sync/sync_pending_state_store.dart';

/// Dispatches committed mutations through foreground sync or background work.
class ForegroundSyncMutationDispatcher {
  ForegroundSyncMutationDispatcher({
    required Future<bool> Function() foregroundIsActive,
    required Future<void> Function() synchronize,
    required SyncScheduler scheduler,
    SyncPendingStateStore? pending,
    void Function(Object error, StackTrace stackTrace)? reportError,
  }) : _foregroundIsActive = foregroundIsActive,
       _synchronize = synchronize,
       _scheduler = scheduler,
       _pending = pending ?? const NoopSyncPendingStateStore(),
       _reportError = reportError;

  final Future<bool> Function() _foregroundIsActive;
  final Future<void> Function() _synchronize;
  final SyncScheduler _scheduler;
  final SyncPendingStateStore _pending;
  final void Function(Object error, StackTrace stackTrace)? _reportError;
  bool _hasPendingMutation = false;
  bool _dispatching = false;
  bool _followUpNeeded = false;
  bool _backgroundHandoffRequested = false;

  /// Starts a non-blocking attempt after local state has been committed.
  void mutationCommitted() {
    _hasPendingMutation = true;
    if (_dispatching) {
      _followUpNeeded = true;
      return;
    }
    _dispatching = true;
    unawaited(_dispatch());
  }

  /// Hands pending work to WorkManager after foreground ownership ends.
  void foregroundBecameInactive() {
    _backgroundHandoffRequested = true;
    if (!_dispatching) unawaited(_handoffIfPending());
  }

  /// Cancels a prior background handoff once foreground ownership resumes.
  void foregroundBecameActive() {
    _backgroundHandoffRequested = false;
  }

  Future<void> _dispatch() async {
    try {
      if (!await _foregroundIsActive()) {
        await _scheduleBackground();
        return;
      }
      while (true) {
        final attempt = await _pending.readPendingRevision();
        try {
          await _synchronize();
        } catch (error, stackTrace) {
          _reportError?.call(error, stackTrace);
          await _scheduleBackground();
          return;
        }
        if (attempt != null) await _pending.clearIfMatches(attempt);
        if (!_followUpNeeded) break;
        _followUpNeeded = false;
      }
      _hasPendingMutation = await _pending.readPendingRevision() != null;
    } catch (error, stackTrace) {
      _reportError?.call(error, stackTrace);
      await _scheduleBackground();
    } finally {
      _dispatching = false;
      if (_backgroundHandoffRequested) {
        await _scheduleBackground();
      }
    }
  }

  Future<void> _scheduleBackground() async {
    var hasPending = _hasPendingMutation;
    try {
      hasPending = hasPending || await _pending.readPendingRevision() != null;
    } catch (error, stackTrace) {
      _reportError?.call(error, stackTrace);
    }
    if (!hasPending) {
      return;
    }
    try {
      await _scheduler.schedule();
    } catch (error, stackTrace) {
      _reportError?.call(error, stackTrace);
    }
  }

  Future<void> _handoffIfPending() async {
    await _scheduleBackground();
  }
}
