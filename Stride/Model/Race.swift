import Foundation
import StrideCore

/// Where today stands against earlier days at the same time of day.
struct RaceStatus: Equatable {
    struct Rival: Equatable, Identifiable {
        let name: String
        let day: Day
        /// Steps that day by this time of day.
        let stepsByNow: Int
        /// Steps that day in total.
        let dayTotal: Int

        var id: Day { day }
    }

    let rivals: [Rival]
    let asOf: Date
}

extension RaceStatus {
    /// Yesterday, plus the best of the six days before today if it isn't yesterday.
    static func rivalDays(today: Day, summary: RewardSummary) -> [(name: String, day: Day, total: Int)] {
        let yesterday = today.adding(days: -1)
        var days = [(name: "Yesterday", day: yesterday, total: summary.result(for: yesterday)?.steps ?? 0)]
        let week = today.adding(days: -6).through(today.adding(days: -1)).compactMap { summary.result(for: $0) }
        if let best = week.max(by: { $0.steps < $1.steps }), best.day != yesterday, best.steps > 0 {
            let weekday = best.day.startDate().formatted(.dateTime.weekday(.wide))
            days.append((name: "Best day: \(weekday)", day: best.day, total: best.steps))
        }
        return days
    }

    /// A made-up race for sample data: earlier days' steps spread evenly over waking hours.
    static func sample(today: Day, summary: RewardSummary, now: Date) -> RaceStatus {
        let wakingFraction = min(1, max(0, (now.timeIntervalSince(today.startDate()) / 3600 - 7) / 15))
        let rivals = rivalDays(today: today, summary: summary).map {
            Rival(name: $0.name, day: $0.day, stepsByNow: Int(Double($0.total) * wakingFraction), dayTotal: $0.total)
        }
        return RaceStatus(rivals: rivals, asOf: now)
    }
}
