import 'package:flutter/services.dart';

/// Acquires Android's process-wide foreground/background sync execution lock.
abstract interface class SyncExecutionLockPort {
  Future<void> acquire({required int timeoutMillis});

  Future<void> release();
}

/// Production MethodChannel implementation of [SyncExecutionLockPort].
class MethodChannelSyncExecutionLockPort implements SyncExecutionLockPort {
  const MethodChannelSyncExecutionLockPort({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'mytime/sync_execution_lock';
  final MethodChannel _channel;

  @override
  Future<void> acquire({required int timeoutMillis}) async {
    final acquired = await _channel.invokeMethod<bool>('acquire', {
      'timeoutMillis': timeoutMillis,
    });
    if (acquired != true) {
      throw StateError('Android sync execution lock acquisition timed out');
    }
  }

  @override
  Future<void> release() => _channel.invokeMethod<void>('release');
}

/// Explicit test-only port for code paths that do not require native locking.
class NoopSyncExecutionLockPort implements SyncExecutionLockPort {
  const NoopSyncExecutionLockPort();

  @override
  Future<void> acquire({required int timeoutMillis}) async {}

  @override
  Future<void> release() async {}
}
