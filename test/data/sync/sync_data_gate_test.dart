import 'dart:async';

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
}
