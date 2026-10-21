import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let ember = Color(red: 1, green: 0.416, blue: 0.169)
private let gold = Color(red: 1, green: 0.79, blue: 0.29)
private let ringColors = [Color(red: 1, green: 0.76, blue: 0.28), ember, Color(red: 1, green: 0.18, blue: 0.43)]

/// Today's steps on the Lock Screen and in the Dynamic Island, with the walk in progress when there is one.
struct StrideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StrideActivityAttributes.self) { context in
            LockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.todaySteps.formatted())
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(state.todaySteps)))
                        Text("steps today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    GoalRing(fraction: state.goalFraction, lineWidth: 5) {
                        Text("\(Int(state.goalFraction * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .frame(width: 48, height: 48)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let walk = state.walk {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label {
                                    Text(timerInterval: walk.startedAt...Date.distantFuture, pauseTime: walk.pausedAt,
                                         countsDown: false)
                                        .monospacedDigit()
                                } icon: {
                                    Image(systemName: walk.pausedAt == nil ? "figure.walk" : "pause.fill")
                                        .foregroundStyle(ember)
                                }
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("\(walk.steps.formatted()) steps · \(state.distanceText(walk.meters))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Spacer(minLength: 0)
                            WalkButtons(isPaused: walk.pausedAt != nil)
                        }
                        .padding(.horizontal, 4)
                    } else {
                        VStack(spacing: 6) {
                            GoalBar(fraction: state.goalFraction)
                            HStack {
                                Text(state.stepsToGo > 0 ? "\(state.stepsToGo.formatted()) to go" as String : "Goal reached")
                                Spacer()
                                Text("Level \(state.level)")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                Image(systemName: state.walk?.pausedAt == nil ? "figure.walk" : "pause.fill")
                    .foregroundStyle(state.walk == nil ? (state.goalFraction >= 1 ? gold : ember) : ember)
            } compactTrailing: {
                Text(state.todaySteps.formatted())
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(state.todaySteps)))
                    .frame(maxWidth: 64)
            } minimal: {
                GoalRing(fraction: state.goalFraction, lineWidth: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .keylineTint(ember)
        }
    }
}

private struct LockScreenView: View {
    let state: StrideActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 16) {
            GoalRing(fraction: state.goalFraction, lineWidth: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 2) {
                if let walk = state.walk {
                    HStack(spacing: 6) {
                        Text(walk.pausedAt == nil ? "WALKING" as String : "PAUSED")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(walk.pausedAt == nil ? ember : gold)
                        Text(timerInterval: walk.startedAt...Date.distantFuture, pauseTime: walk.pausedAt, countsDown: false)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text("\(walk.steps.formatted()) steps")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("\(state.distanceText(walk.meters)) · \(state.todaySteps.formatted()) of \(state.goal.formatted()) today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(state.goalFraction >= 1 ? gold : ember)
                    Text("\(state.todaySteps.formatted()) steps")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(state.todaySteps)))
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
            if let walk = state.walk {
                WalkButtons(isPaused: walk.pausedAt != nil)
            }
        }
        .padding(16)
    }

    private var detail: String {
        if isStale { return "Open Stride to update" }
        let progress = state.stepsToGo > 0 ? "\(state.stepsToGo.formatted()) to go" : "Goal reached"
        return "\(progress) · Level \(state.level)"
    }
}

/// Pause or resume, and end, without opening Stride.
private struct WalkButtons: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isPaused {
                Button(intent: ResumeWalkIntent()) { icon("play.fill", label: "Resume") }
            } else {
                Button(intent: PauseWalkIntent()) { icon("pause.fill", label: "Pause") }
            }
            Button(intent: EndWalkIntent()) { icon("stop.fill", label: "End walk") }
        }
        .buttonStyle(.plain)
    }

    private func icon(_ symbol: String, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(Color.white.opacity(0.16), in: Circle())
            .accessibilityLabel(label)
    }
}

private struct GoalRing<Center: View>: View {
    let fraction: Double
    let lineWidth: CGFloat
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(fraction, 0.001))
                .stroke(fraction >= 1
                        ? AnyShapeStyle(gold)
                        : AnyShapeStyle(AngularGradient(colors: ringColors, center: .center)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
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
