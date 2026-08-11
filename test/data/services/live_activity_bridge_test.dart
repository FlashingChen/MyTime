import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/services/live_activity_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(LiveActivityBridge.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start forwards startTime as milliseconds since epoch', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final bridge = LiveActivityBridge();
    final startTime = DateTime.fromMillisecondsSinceEpoch(
      1700000000123,
      isUtc: true,
    );

    expect(await bridge.start(startTime: startTime), isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {'startTime': 1700000000123});
  });

  test('end invokes the end method', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final bridge = LiveActivityBridge();

    expect(await bridge.end(), isTrue);
    expect(calls.single.method, 'end');
  });

  test('start swallows a platform rejection and reports failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'start-failed'),
        );

    final bridge = LiveActivityBridge();

    expect(await bridge.start(startTime: DateTime.now()), isFalse);
  });

  test('calls are no-ops when no native handler is registered', () async {
    final bridge = LiveActivityBridge();

    // No mock handler: the test messenger answers with MissingPluginException.
    expect(await bridge.start(startTime: DateTime.now()), isFalse);
    expect(await bridge.end(), isFalse);
  });

  test('native stopTimer invokes onStopRequested', () async {
    final bridge = LiveActivityBridge();
    var stopped = false;
    bridge.onStopRequested = () => stopped = true;

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('stopTimer'),
          ),
          (_) {},
        );

    expect(stopped, isTrue);
  });

  test('native stopTimer is dropped when no handler is attached', () async {
    // Constructing the bridge registers the incoming-call handler; without
    // `onStopRequested` the native message must be a harmless no-op.
    LiveActivityBridge();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('stopTimer'),
          ),
          (_) {},
        );

    // Unknown native calls must also be answered, not crash.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('someOtherCall'),
          ),
          (_) {},
        );
  });
}
