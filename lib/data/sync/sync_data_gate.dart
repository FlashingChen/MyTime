import 'dart:async';

/// Serializes local writes with destructive remote snapshot replacement.
class SyncDataGate {
  SyncDataGate();

  Future<void> _tail = Future<void>.value();
  static final Object _zoneKey = Object();

  /// Runs [operation] after earlier guarded data mutations have finished.
  Future<T> run<T>(Future<T> Function() operation) {
    if (Zone.current[_zoneKey] == this) return operation();
    final queued = _tail.then<T>(
      (_) => runZoned(operation, zoneValues: {_zoneKey: this}),
    );
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return queued;
  }
}
