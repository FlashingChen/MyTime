import 'dart:async';

import 'package:mytime/data/sync/sync_scheduler.dart';

/// Dispatches committed mutations through foreground sync or background work.
class ForegroundSyncMutationDispatcher {
  ForegroundSyncMutationDispatcher({
    required Future<bool> Function() foregroundIsActive,
    required Future<void> Function() synchronize,
    required SyncScheduler scheduler,
    void Function(Object error, StackTrace stackTrace)? reportError,
  }) : _foregroundIsActive = foregroundIsActive,
       _synchronize = synchronize,
       _scheduler = scheduler,
       _reportError = reportError;

  final Future<bool> Function() _foregroundIsActive;
  final Future<void> Function() _synchronize;
  final SyncScheduler _scheduler;
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
    if (!_dispatching && _hasPendingMutation) unawaited(_scheduleBackground());
  }

  /// Cancels a prior background handoff once foreground ownership resumes.
  void foregroundBecameActive() {
    _backgroundHandoffRequested = false;
  }

  Future<void> _dispatch() async {
    if (!await _foregroundIsActive()) {
      await _scheduleBackground();
      return;
    }

    try {
      while (true) {
        try {
          await _synchronize();
        } catch (error, stackTrace) {
          _reportError?.call(error, stackTrace);
          if (_backgroundHandoffRequested) await _scheduleBackground();
          return;
        }
        if (!_followUpNeeded) break;
        _followUpNeeded = false;
      }
      _hasPendingMutation = false;
    } finally {
      _dispatching = false;
      if (_backgroundHandoffRequested && _hasPendingMutation) {
        await _scheduleBackground();
      }
    }
  }

  Future<void> _scheduleBackground() async {
    if (!_hasPendingMutation) return;
    try {
      await _scheduler.schedule();
    } catch (error, stackTrace) {
      _reportError?.call(error, stackTrace);
    }
  }
}
