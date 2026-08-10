import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mytime/data/services/live_activity_bridge.dart';

/// End-to-end check of the `mytime/live_activity` channel against the real
/// ActivityKit implementation (requires an iOS simulator or device).
///
/// Run with: `flutter test integration_test/live_activity_test.dart -d <device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live activity start and end round-trip on the real channel', (
    tester,
  ) async {
    if (!Platform.isIOS) {
      markTestSkipped(
        'Live Activity round-trip requires an iOS simulator or device.',
      );
      return;
    }

    final bridge = LiveActivityBridge();

    final started = await bridge.start(startTime: DateTime.now());
    expect(
      started,
      isTrue,
      reason: 'ActivityKit should accept a timer activity on iOS 16.2+',
    );

    final ended = await bridge.end();
    expect(ended, isTrue, reason: 'ending an active activity must succeed');
  });
}
