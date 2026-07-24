import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';
import 'package:mytime/data/sync/sync_execution_lock_port.dart';

void main() {
  test('serializes operations in the same foreground gate', () async {
    final gate = SyncDataGate(lock: _RecordingLock());
    final entered = Completer<void>();
    final release = Completer<void>();
    var secondStarted = false;

    final firstRun = gate.run(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final secondRun = gate.run(() async => secondStarted = true);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(secondStarted, isFalse);
    release.complete();
    await Future.wait([firstRun, secondRun]);
    expect(secondStarted, isTrue);
  });

  test('does not serialize separate foreground gates', () async {
    final first = SyncDataGate(lock: _RecordingLock());
    final second = SyncDataGate(lock: _RecordingLock());
    final entered = Completer<void>();
    final release = Completer<void>();
    var secondStarted = false;

    final firstRun = first.run(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final secondRun = second.run(() async => secondStarted = true);

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(secondStarted, isTrue);
    release.complete();
    await Future.wait([firstRun, secondRun]);
  });

  test(
    'acquires and releases the native lock around a successful operation',
    () async {
      final lock = _RecordingLock();
      final result = await SyncDataGate(lock: lock).run(() async => 'complete');

      expect(result, 'complete');
      expect(lock.events, ['acquire', 'release']);
    },
  );

  test('releases the native lock when its operation throws', () async {
    final lock = _RecordingLock();

    await expectLater(
      SyncDataGate(lock: lock).run<void>(() async => throw StateError('boom')),
      throwsStateError,
    );

    expect(lock.events, ['acquire', 'release']);
  });

  test('bypasses the native lock for native-owned background work', () async {
    final lock = _RecordingLock();

    await SyncDataGate(lock: lock, bypassNativeLock: true).run(() async {});

    expect(lock.events, isEmpty);
  });
}

class _RecordingLock implements SyncExecutionLockPort {
  final events = <String>[];

  @override
  Future<void> acquire({int? timeoutMillis}) async {
    events.add('acquire');
  }

  @override
  Future<void> release() async {
    events.add('release');
  }
}
