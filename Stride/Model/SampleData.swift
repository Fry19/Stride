import Foundation
import StrideCore

/// Made-up walking history for trying the app in the simulator, where there are no real steps.
enum SampleData {
    static let dayCount = 60

    static func activity(endingOn today: Day) -> (startDay: Day, activity: [DayActivity]) {
        var seed: UInt64 = 7
        func random() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(UInt64(1) << 31)
        }

        let start = today.adding(days: -(dayCount - 1))
        let activity = start.through(today).map { day -> DayActivity in
            var steps = 5_000 + random() * 8_000
            if day == today { steps *= 0.55 }
            return DayActivity(day: day, steps: Int(steps), meters: steps * 0.74)
        }
        return (start, activity)
    }
}
