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
      '${Directory.systemTemp.path}${Platform.pathSeparator}mytime_sync.mutex';
  static const _staleLockAge = Duration(minutes: 10);

  /// Runs [operation] after earlier guarded data mutations have finished.
  Future<T> run<T>(Future<T> Function() operation) {
    if (identical(Zone.current[_zoneKey], this)) return operation();
    final queued = _tail.then<T>((_) => _runLocked(operation));
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return queued;
  }

  Future<T> _runLocked<T>(Future<T> Function() operation) async {
    final lock = File(_lockPath);
    final token = '$pid-${DateTime.now().microsecondsSinceEpoch}';
    try {
      while (true) {
        try {
          // Exclusive file creation is atomic across isolates in the same
          // process, unlike POSIX advisory file locks, which are process-scoped.
          await lock.create(exclusive: true);
          await lock.writeAsString(token);
          break;
        } on FileSystemException {
          DateTime modified;
          try {
            modified = await lock.lastModified();
          } on FileSystemException {
            continue;
          }
          if (DateTime.now().toUtc().difference(modified.toUtc()) >
              _staleLockAge) {
            await lock.delete();
            continue;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      return await runZoned(
        operation,
        zoneValues: <Object, Object>{_zoneKey: this},
      );
    } finally {
      if (await lock.exists() && await lock.readAsString() == token) {
        await lock.delete();
      }
    }
  }
}
