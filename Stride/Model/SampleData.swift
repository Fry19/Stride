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

    /// Two made-up walks around the Central Park Reservoir in New York.
    static func walks(endingOn today: Day) -> [Walk] {
        let center = (latitude: 40.7829, longitude: -73.9626)
        let loop = (0...48).map { index -> Walk.Point in
            let angle = Double(index) / 48 * 2 * .pi
            return Walk.Point(latitude: center.latitude + 0.0042 * sin(angle),
                              longitude: center.longitude + 0.0036 * cos(angle))
        }
        return [(1, 9.5, 3_412, 2_520.0), (3, 18.25, 5_160, 3_890.0)].map { daysAgo, hour, steps, meters in
            let start = today.adding(days: -daysAgo).startDate().addingTimeInterval(hour * 3600)
            return Walk(id: UUID(), start: start, end: start.addingTimeInterval(Double(steps) / 105 * 60),
                        steps: steps, meters: meters, route: loop)
        }
    }
}
