import 'dart:async';

import 'package:mytime/data/sync/sync_execution_lock_port.dart';

/// Serializes local writes with destructive remote snapshot replacement.
class SyncDataGate {
  SyncDataGate({SyncExecutionLockPort? lock, this.bypassNativeLock = false})
    : _lock = lock ?? const NoopSyncExecutionLockPort();

  final SyncExecutionLockPort _lock;
  final bool bypassNativeLock;
  Future<void> _tail = Future<void>.value();

  /// Runs [operation] after earlier guarded data mutations have finished.
  Future<T> run<T>(Future<T> Function() operation) {
    final queued = _tail.then<T>((_) async {
      if (bypassNativeLock) return operation();
      final token = await _lock.acquire();
      try {
        return await operation();
      } finally {
        await _lock.release(token);
      }
    });
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return queued;
  }
}
