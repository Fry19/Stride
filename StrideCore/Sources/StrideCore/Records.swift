import Foundation

/// Personal bests from the step history.
public struct StepRecords: Equatable {
    /// Steps over a week or month, and the day it began.
    public struct Period: Equatable {
        public let start: Day
        public let steps: Int
    }

    public let bestDay: DayResult?
    public let bestWeek: Period?
    public let bestMonth: Period?
    public let longestStreak: Int
    public let goalDays: Int
    public let totalSteps: Int
    public let totalMeters: Double
    /// Average over days with any steps.
    public let dailyAverage: Int

    /// Weeks start on `firstWeekday`, 1 for Sunday or 2 for Monday.
    public init(summary: RewardSummary, firstWeekday: Int = 2) {
        let walked = summary.days.filter { $0.steps > 0 }
        bestDay = walked.max { ($0.steps, $1.day) < ($1.steps, $0.day) }

        var weeks: [Day: Int] = [:]
        var months: [Day: Int] = [:]
        for result in walked {
            weeks[result.day.startOfWeek(firstWeekday: firstWeekday), default: 0] += result.steps
            months[Day(year: result.day.year, month: result.day.month, day: 1), default: 0] += result.steps
        }
        bestWeek = Self.best(weeks)
        bestMonth = Self.best(months)

        longestStreak = summary.bestStreak
        goalDays = summary.days.filter { $0.status == .met }.count
        totalSteps = walked.reduce(0) { $0 + $1.steps }
        totalMeters = walked.reduce(0) { $0 + $1.meters }
        dailyAverage = walked.isEmpty ? 0 : totalSteps / walked.count
    }

    /// The highest total, and the earliest one on a tie.
    private static func best(_ totals: [Day: Int]) -> Period? {
        totals.max { ($0.value, $1.key) < ($1.value, $0.key) }.map { Period(start: $0.key, steps: $0.value) }
    }
}
