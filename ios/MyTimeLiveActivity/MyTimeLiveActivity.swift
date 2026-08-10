import ActivityKit
import SwiftUI
import WidgetKit

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
        .foregroundStyle(.indigo)
      ElapsedTimeText(startDate: context.state.startDate)
        .font(.system(.title2, design: .rounded).weight(.semibold))
      Spacer()
      Text("MyTime 计时中")
        .font(.footnote)
        .foregroundStyle(.secondary)
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
        .activitySystemActionForegroundColor(.indigo)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "stopwatch.fill")
            .foregroundStyle(.indigo)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("计时中")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        DynamicIslandExpandedRegion(.center) {
          ElapsedTimeText(startDate: context.state.startDate)
            .font(.system(.headline, design: .rounded).weight(.semibold))
        }
      } compactLeading: {
        Image(systemName: "stopwatch")
      } compactTrailing: {
        ElapsedTimeText(startDate: context.state.startDate)
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .frame(width: 52, alignment: .trailing)
          .minimumScaleFactor(0.8)
      } minimal: {
        Image(systemName: "stopwatch")
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
