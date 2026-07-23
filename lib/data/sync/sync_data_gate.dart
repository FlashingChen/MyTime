import 'dart:async';
import 'dart:io';

/// Serializes local writes with destructive remote snapshot replacement.
///
/// The lock file covers foreground and WorkManager isolates, so replacement
/// rechecks observe every local mutation before writing a merged snapshot.
class SyncDataGate {
  static final Object _zoneKey = Object();
  Future<void> _tail = Future<void>.value();
  static final String _lockPath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}mytime_sync.lock';

  /// Runs [operation] after earlier guarded data mutations have finished.
  Future<T> run<T>(Future<T> Function() operation) {
    if (identical(Zone.current[_zoneKey], this)) return operation();
    final queued = _tail.then<T>((_) => _runLocked(operation));
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return queued;
  }

  Future<T> _runLocked<T>(Future<T> Function() operation) async {
    final lock = await File(_lockPath).open(mode: FileMode.append);
    try {
      while (true) {
        try {
          await lock.lock(FileLock.exclusive);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      return await runZoned(
        operation,
        zoneValues: <Object, Object>{_zoneKey: this},
      );
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }
}
