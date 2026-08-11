import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// MyTime accent and danger red, matching `lib/core/constants/app_colors.dart`
/// (`accentStart` / `danger`).
private let mytimeAccent = Color(red: 0x63 / 255.0, green: 0x66 / 255.0, blue: 0xF1 / 255.0)
private let mytimeStopRed = Color(red: 0xEF / 255.0, green: 0x44 / 255.0, blue: 0x44 / 255.0)

/// Activity attributes for the running MyTime timer.
///
/// Must be byte-identical between the app (Runner) and this extension: the
/// system matches live activities by the encoded attribute shape.
struct MyTimeTimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// Absolute timer start; the UI renders elapsed time from this date.
    var startDate: Date
  }
}

/// Elapsed-time label that ticks on its own via `Text(timerInterval:)`,
/// without consuming the live activity update budget.
struct ElapsedTimeText: View {
  let startDate: Date

  var body: some View {
    Text(
      timerInterval: startDate...Date.distantFuture,
      countsDown: false
    )
    .monospacedDigit()
  }
}

/// Lock Screen presentation.
struct MyTimeLiveActivityView: View {
  let context: ActivityViewContext<MyTimeTimerAttributes>

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "stopwatch.fill")
        .foregroundStyle(mytimeAccent)
      ElapsedTimeText(startDate: context.state.startDate)
        .font(.system(.title2, design: .rounded).weight(.semibold))
      Spacer()
      Button(intent: StopTimerIntent()) {
        Image(systemName: "stop.circle.fill")
          .font(.system(size: 30))
          .foregroundStyle(mytimeStopRed)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 4)
  }
}

/// Dynamic Island presentations (compact / minimal / expanded).
struct MyTimeLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MyTimeTimerAttributes.self) { context in
      MyTimeLiveActivityView(context: context)
        .activityBackgroundTint(Color.black.opacity(0.1))
        .activitySystemActionForegroundColor(mytimeAccent)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "stopwatch.fill")
            .font(.system(size: 20))
            .foregroundStyle(mytimeAccent)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("计时中")
            .font(.caption2)
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.14), in: Capsule())
        }
        DynamicIslandExpandedRegion(.center) {
          ElapsedTimeText(startDate: context.state.startDate)
            .font(.system(.title2, design: .rounded).weight(.bold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          Button(intent: StopTimerIntent()) {
            Label("停止计时", systemImage: "stop.fill")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 9)
              .background(mytimeStopRed, in: Capsule())
          }
          .buttonStyle(.plain)
        }
      } compactLeading: {
        Image(systemName: "stopwatch.fill")
          .foregroundStyle(mytimeAccent)
      } compactTrailing: {
        ElapsedTimeText(startDate: context.state.startDate)
          .font(.system(size: 13, weight: .semibold, design: .rounded))
          .frame(width: 56, alignment: .trailing)
          .minimumScaleFactor(0.7)
      } minimal: {
        Image(systemName: "stopwatch.fill")
          .foregroundStyle(mytimeAccent)
      }
    }
  }
}

@main
struct MyTimeLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    MyTimeLiveActivityWidget()
  }
}
