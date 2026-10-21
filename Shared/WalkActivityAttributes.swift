import ActivityKit
import Foundation

/// The Live Activity shown on the Lock Screen and Dynamic Island during a walk.
/// Shared by the app, which starts and updates it, and the widget extension, which draws it.
struct WalkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Steps on this walk.
        var steps: Int
        var meters: Double
        /// Steps today, including this walk.
        var todaySteps: Int
        var goal: Int
        var usesMiles: Bool
    }

    var startedAt: Date
    var level: Int
}

extension WalkActivityAttributes.ContentState {
    var distanceText: String {
        let value = usesMiles ? meters / 1_609.344 : meters / 1_000
        return "\(value.formatted(.number.precision(.fractionLength(2)))) \(usesMiles ? "mi" : "km")"
    }

    var goalFraction: Double {
        goal > 0 ? min(1, Double(todaySteps) / Double(goal)) : 0
    }
}
