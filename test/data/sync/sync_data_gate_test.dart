import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';

void main() {
  test('serializes operations in the same foreground gate', () async {
    final gate = SyncDataGate();
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
    final first = SyncDataGate();
    final second = SyncDataGate();
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

  test('allows a nested operation in the same gate', () async {
    final gate = SyncDataGate();

    await expectLater(gate.run(() => gate.run(() async {})), completes);
  });

  test('continues serializing operations after a failed operation', () async {
    final gate = SyncDataGate();
    final order = <String>[];

    await expectLater(
      gate.run(() async {
        order.add('failed');
        throw StateError('expected failure');
      }),
      throwsStateError,
    );
    await gate.run(() async => order.add('after failure'));

    expect(order, ['failed', 'after failure']);
  });
}
