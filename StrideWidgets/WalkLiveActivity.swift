import ActivityKit
import SwiftUI
import WidgetKit

private let ember = Color(red: 1, green: 0.416, blue: 0.169)
private let ringColors = [Color(red: 1, green: 0.76, blue: 0.28), ember, Color(red: 1, green: 0.18, blue: 0.43)]

/// Live steps, distance and time for a walk, on the Lock Screen and in the Dynamic Island.
struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            LockScreenWalkView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                            .frame(width: 64, alignment: .leading)
                    } icon: {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(ember)
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.steps.formatted()) steps")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        GoalBar(fraction: context.state.goalFraction)
                        HStack {
                            Text(context.state.distanceText)
                            Spacer()
                            Text("\(context.state.todaySteps.formatted()) of \(context.state.goal.formatted()) today")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(ember)
            } compactTrailing: {
                Text(context.state.steps.formatted(.number.notation(.compactName)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(ember)
            }
            .keylineTint(ember)
        }
    }
}

private struct LockScreenWalkView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(context.state.goalFraction, 0.001))
                    .stroke(AngularGradient(colors: ringColors, center: .center),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("WALKING")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ember)
                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text("\(context.state.steps.formatted()) steps")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("\(context.state.distanceText) · \(context.state.todaySteps.formatted()) of \(context.state.goal.formatted()) today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            Text("Lv \(context.attributes.level)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
    }
}

private struct GoalBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: ringColors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geometry.size.width * fraction))
            }
        }
        .frame(height: 6)
    }
}
