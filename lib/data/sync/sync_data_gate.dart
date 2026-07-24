import 'dart:async';

/// Serializes local writes with destructive remote snapshot replacement.
class SyncDataGate {
  Future<void> _tail = Future<void>.value();

  /// Runs [operation] after earlier guarded data mutations have finished.
  Future<T> run<T>(Future<T> Function() operation) {
    final queued = _tail.then<T>((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return queued;
  }
}
