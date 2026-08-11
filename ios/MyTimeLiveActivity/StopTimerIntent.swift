import ActivityKit
import AppIntents
import Foundation

/// Process-local notification posted when the user presses stop on the Live
/// Activity. Lives outside the iOS 17-gated intent so the app-side plugin
/// (deployment target iOS 14) can observe it; both targets compile this file.
let mytimeLiveActivityDidStopNotification = Notification.Name(
  "MyTimeLiveActivityDidStop"
)

/// Stops the running MyTime timer from the Live Activity's stop button
/// (Dynamic Island expanded view / Lock Screen).
///
/// Interactive Live Activity controls require iOS 17.0. The intent is
/// compiled into both the app and the widget extension, but executes in the
/// app process — the system launches the app in the background if it is not
/// running. It must therefore not depend on the Flutter engine being
/// attached:
/// 1. persists the stop time under the same `shared_preferences` key the
///    Dart `ActiveTimerRepository` uses (`flutter.` prefix, local ISO 8601),
///    so the next app launch restores the pending-confirmation state;
/// 2. ends the Live Activity immediately;
/// 3. posts a process-local notification the app-side plugin observes (when
///    the engine is attached) to dispatch `stopTimer` over the
///    `mytime/live_activity` channel, so a running app stops its UI at once.
@available(iOS 17.0, *)
struct StopTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource { "停止计时" }

  func perform() async throws -> some IntentResult {
    // Key must match `ActiveTimerRepository._keyStoppedAt` with the
    // `flutter.` prefix `shared_preferences` adds on iOS.
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    UserDefaults.standard.set(
      formatter.string(from: Date()),
      forKey: "flutter.active_timer_stopped_at"
    )
    // Retire the activity right away; mirrors the app's "at most one
    // activity" policy.
    let endContent: ActivityContent<MyTimeTimerAttributes.ContentState>? = nil
    for activity in Activity<MyTimeTimerAttributes>.activities {
      await activity.end(endContent, dismissalPolicy: .immediate)
    }
    NotificationCenter.default.post(
      name: mytimeLiveActivityDidStopNotification,
      object: nil
    )
    return .result()
  }
}
