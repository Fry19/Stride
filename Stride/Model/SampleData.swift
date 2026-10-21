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

    /// The Camino de Santiago, started on the first day of sample data.
    static func journeys(startDay: Day) -> [JourneyPlan] {
        Journeys.epic.first { $0.id == "camino" }.map { [JourneyPlan(route: $0, startDay: startDay)] } ?? []
    }

    /// The first `count` of 48 points around the Central Park Reservoir in New York, counterclockwise
    /// from its north end: an ellipse lined up with the park, which runs 29° east of north.
    static func reservoirLap(points count: Int = 49) -> [Walk.Point] {
        let center = (latitude: 40.7853, longitude: -73.9622)
        let (alongPark, acrossPark, tilt) = (420.0, 350.0, 29.0 * .pi / 180)
        let metersPerDegree = 111_320.0
        return (0..<count).map { index in
            let angle = Double(index) / 48 * 2 * .pi
            let along = alongPark * cos(angle), across = -acrossPark * sin(angle)
            let east = along * sin(tilt) + across * cos(tilt)
            let north = along * cos(tilt) - across * sin(tilt)
            return Walk.Point(latitude: center.latitude + north / metersPerDegree,
                              longitude: center.longitude + east / (metersPerDegree * cos(center.latitude * .pi / 180)))
        }
    }

    /// Two made-up laps of the Central Park Reservoir.
    static func walks(endingOn today: Day) -> [Walk] {
        let loop = reservoirLap()
        return [(1, 9.5, 3_412, 2_520.0), (3, 18.25, 5_160, 3_890.0)].map { daysAgo, hour, steps, meters in
            let start = today.adding(days: -daysAgo).startDate().addingTimeInterval(hour * 3600)
            return Walk(id: UUID(), start: start, end: start.addingTimeInterval(Double(steps) / 105 * 60),
                        steps: steps, meters: meters, route: loop)
        }
    }
}
