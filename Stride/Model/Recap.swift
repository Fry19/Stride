import Foundation
import StrideCore

/// Totals for a stretch of days, for the shareable recap card.
struct Recap: Equatable {
    enum Period: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"

        var id: String { rawValue }
    }

    let period: Period
    let title: String
    let dateRange: String
    let totalSteps: Int
    let averageSteps: Int
    let goalDays: Int
    let dayCount: Int
    let bestDay: DayResult?
    let xp: Int
    let meters: Double
    let level: LevelProgress
    let bestStreak: Int

    /// The last 7 days, or the calendar month so far.
    init(period: Period, summary: RewardSummary) {
        let today = summary.today
        let first: Day
        switch period {
        case .week:
            first = today.adding(days: -6)
            title = "My week on Stride"
        case .month:
            first = Day(year: today.year, month: today.month, day: 1)
            title = "My \(today.startDate().formatted(.dateTime.month(.wide))) on Stride"
        }
        let days = first.through(today).map { summary.result(for: $0) }
        let results = days.compactMap { $0 }
        self.period = period
        dateRange = "\(StrideFormat.date(first)) – \(StrideFormat.date(today))"
        totalSteps = results.reduce(0) { $0 + $1.steps }
        dayCount = days.count
        averageSteps = days.isEmpty ? 0 : totalSteps / days.count
        goalDays = results.filter(\.goalMet).count
        bestDay = results.max { $0.steps < $1.steps }
        xp = results.reduce(0) { $0 + $1.xp }
        meters = results.reduce(0) { $0 + $1.meters }
        level = summary.level

        var streak = 0
        var best = 0
        for result in days {
            if result?.goalMet == true {
                streak += 1
                best = max(best, streak)
            } else {
                streak = 0
            }
        }
        bestStreak = best
    }
}
