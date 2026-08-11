import ActivityKit
import Flutter
import UIKit

/// Activity attributes for the running MyTime timer.
///
/// Must be byte-identical to the definition in the MyTimeLiveActivity
/// extension: the system matches live activities by the encoded attribute
/// shape, so both modules declare the same type.
struct MyTimeTimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// Absolute timer start; the extension renders elapsed time from it.
    var startDate: Date
  }
}

/// Bridges the running MyTime timer to a Live Activity (Dynamic Island and
/// Lock Screen) via ActivityKit.
///
/// Channel: `mytime/live_activity`
/// - `start` { startTime: millisecondsSinceEpoch } — starts the activity
/// - `end` — ends the activity
/// - (native → Dart) `stopTimer` — the user pressed stop on the activity
///
/// The extension renders the elapsed time from the absolute `startDate`, so
/// no per-second updates are needed and the tick does not consume the Live
/// Activity update budget.
///
/// Interactive Live Activity controls require iOS 17.0; on earlier versions
/// every call is a best-effort no-op and the timer never depends on this
/// feature.
final class LiveActivityPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "mytime/live_activity",
      binaryMessenger: registrar.messenger()
    )
    let instance = LiveActivityPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    // The stop button's intent executes in this process; when the engine is
    // attached it forwards the request to Dart over the channel. Without an
    // attached engine there is no observer and the intent's persisted state
    // covers the stop.
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(timerStopRequested),
      name: mytimeLiveActivityDidStopNotification,
      object: nil
    )
  }

  @objc private func timerStopRequested() {
    channel.invokeMethod("stopTimer", arguments: nil)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      guard #available(iOS 17.0, *) else {
        result(
          FlutterError(
            code: "unsupported",
            message: "Live Activities require iOS 17.0 or later.",
            details: nil
          )
        )
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let milliseconds = arguments["startTime"] as? NSNumber
      else {
        result(
          FlutterError(
            code: "invalid-arguments",
            message: "Missing startTime.",
            details: nil
          )
        )
        return
      }
      let startDate = Date(timeIntervalSince1970: milliseconds.doubleValue / 1000.0)
      startActivity(startDate: startDate, result: result)
    case "end":
      guard #available(iOS 17.0, *) else {
        result(nil)
        return
      }
      endActivity(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 17.0, *)
  private func startActivity(startDate: Date, result: @escaping FlutterResult) {
    let attributes = MyTimeTimerAttributes()
    let content = ActivityContent(
      state: MyTimeTimerAttributes.ContentState(startDate: startDate),
      staleDate: nil
    )
    Task {
      // Retire any leftover activities from a previous app run so at most one
      // MyTime activity exists (the system only surfaces the newest anyway).
      await LiveActivityPlugin.endAllActivities()
      do {
        _ = try Activity.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "start-failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  @available(iOS 17.0, *)
  private func endActivity(result: @escaping FlutterResult) {
    Task {
      await LiveActivityPlugin.endAllActivities()
      result(nil)
    }
  }

  /// Ends every MyTime activity, matching the "at most one activity" policy.
  @available(iOS 17.0, *)
  static func endAllActivities() async {
    let endContent: ActivityContent<MyTimeTimerAttributes.ContentState>? = nil
    for activity in Activity<MyTimeTimerAttributes>.activities {
      await activity.end(endContent, dismissalPolicy: .immediate)
    }
  }
}
