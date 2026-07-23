import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';

void main() {
  test(
    'separate gates serialize access through the shared directory mutex',
    () async {
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
      final secondRun = second.run(() async {
        secondStarted = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(secondStarted, isFalse);
      release.complete();
      await Future.wait([firstRun, secondRun]);
      expect(secondStarted, isTrue);
    },
  );

  test('reclaims a lock left by a terminated synchronization', () async {
    final lock = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}mytime_sync.mutex',
    );
    await lock.writeAsString('stale');
    await lock.setLastModified(
      DateTime.now().subtract(const Duration(minutes: 11)),
    );

    var ran = false;
    await SyncDataGate().run(() async => ran = true);

    expect(ran, isTrue);
  });
}
