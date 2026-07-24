import 'package:flutter/services.dart';

/// Acquires Android's process-wide foreground/background sync execution lock.
abstract interface class SyncExecutionLockPort {
  Future<String> acquire({int? timeoutMillis});

  Future<bool> release(String token);
}

/// Production MethodChannel implementation of [SyncExecutionLockPort].
class MethodChannelSyncExecutionLockPort implements SyncExecutionLockPort {
  const MethodChannelSyncExecutionLockPort({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'mytime/sync_execution_lock';
  final MethodChannel _channel;

  @override
  Future<String> acquire({int? timeoutMillis}) async {
    final token = await _channel.invokeMethod<String>('acquire', {
      if (timeoutMillis != null) 'timeoutMillis': timeoutMillis,
    });
    if (token == null) {
      throw StateError('Android sync execution lock acquisition timed out');
    }
    return token;
  }

  @override
  Future<bool> release(String token) async =>
      await _channel.invokeMethod<bool>('release', {'token': token}) ?? false;
}

/// Explicit test-only port for code paths that do not require native locking.
class NoopSyncExecutionLockPort implements SyncExecutionLockPort {
  const NoopSyncExecutionLockPort();

  @override
  Future<String> acquire({int? timeoutMillis}) async => 'noop';

  @override
  Future<bool> release(String token) async => true;
}
