import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges the running timer to the iOS Live Activity (Dynamic Island and
/// Lock Screen) via the native ActivityKit channel.
///
/// The extension renders the elapsed time from the absolute start time, so
/// this bridge is only invoked on timer start/stop — never on ticks.
///
/// On platforms or iOS versions without Live Activity support the calls are
/// best-effort no-ops, so the timer itself never depends on this feature.
class LiveActivityBridge {
  LiveActivityBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// Invoked when the user presses "stop" on the Live Activity (Dynamic
  /// Island / Lock Screen). The UI wires this to `TimerStopped`.
  VoidCallback? onStopRequested;

  /// Native channel name, also used by tests to intercept calls.
  static const channelName = 'mytime/live_activity';

  final MethodChannel _channel;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'stopTimer') {
      onStopRequested?.call();
    }
    return null;
  }

  /// Shows the running timer in the Live Activity starting at [startTime].
  ///
  /// Returns `false` when the platform does not support Live Activities or
  /// the native side rejected the request; the timer keeps running either way.
  Future<bool> start({required DateTime startTime}) =>
      _invoke('start', {'startTime': startTime.millisecondsSinceEpoch});

  /// Removes the Live Activity. Safe to call when none is active.
  Future<bool> end() => _invoke('end');

  Future<bool> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on PlatformException catch (error) {
      debugPrint('LiveActivityBridge.$method failed: ${error.message}');
      return false;
    } on MissingPluginException {
      // Not running on iOS (or plugin not registered): nothing to update.
      return false;
    }
  }
}
