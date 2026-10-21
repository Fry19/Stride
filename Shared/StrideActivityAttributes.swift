import ActivityKit
import Foundation

/// The Live Activity on the Lock Screen and in the Dynamic Island: today's steps all day,
/// with the walk in progress added on top. Shared by the app, which starts and updates it,
/// and the widget extension, which draws it.
struct StrideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        struct Walk: Codable, Hashable {
            var startedAt: Date
            var steps: Int
            var meters: Double
        }

        var todaySteps: Int
        var goal: Int
        var level: Int
        var usesMiles: Bool
        var walk: Walk?
    }
}

extension StrideActivityAttributes.ContentState {
    var goalFraction: Double {
        goal > 0 ? min(1, Double(todaySteps) / Double(goal)) : 0
    }

    var stepsToGo: Int {
        max(0, goal - todaySteps)
    }

    func distanceText(_ meters: Double) -> String {
        let value = usesMiles ? meters / 1_609.344 : meters / 1_000
        return "\(value.formatted(.number.precision(.fractionLength(2)))) \(usesMiles ? "mi" : "km")"
    }
}
