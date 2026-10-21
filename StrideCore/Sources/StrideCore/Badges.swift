import Foundation

public struct Badge: Identifiable, Hashable {
    public enum Metric: Hashable {
        case daysWalked
        case goalDays
        case bestDaySteps
        case bestStreak
        case lifetimeSteps
        case lifetimeMeters
    }

    public let id: String
    public let name: String
    public let detail: String
    /// SF Symbol name.
    public let symbol: String
    /// XP awarded when the badge is earned.
    public let xp: Int
    public let metric: Metric
    public let target: Double
}

public enum Badges {
    /// Roughly in order of difficulty.
    public static let all: [Badge] = [
        Badge(id: "first-steps", name: "First Steps", detail: "Walk on your first day with Stride",
              symbol: "figure.walk", xp: 200, metric: .daysWalked, target: 1),
        Badge(id: "goal-getter", name: "Goal Getter", detail: "Hit your daily goal",
              symbol: "flag.fill", xp: 500, metric: .goalDays, target: 1),
        Badge(id: "hat-trick", name: "Hat Trick", detail: "Hit your goal 3 days in a row",
              symbol: "flame.fill", xp: 600, metric: .bestStreak, target: 3),
        Badge(id: "10k-club", name: "10K Club", detail: "Walk 10,000 steps in one day",
              symbol: "star.fill", xp: 1_000, metric: .bestDaySteps, target: 10_000),
        Badge(id: "marathon", name: "Marathon", detail: "Walk 42.2 km (26.2 mi) in total",
              symbol: "medal.fill", xp: 1_500, metric: .lifetimeMeters, target: 42_195),
        Badge(id: "full-week", name: "Full Week", detail: "Hit your goal 7 days in a row",
              symbol: "calendar", xp: 1_500, metric: .bestStreak, target: 7),
        Badge(id: "100k", name: "100K", detail: "Walk 100,000 steps in total",
              symbol: "bolt.fill", xp: 2_000, metric: .lifetimeSteps, target: 100_000),
        Badge(id: "big-day", name: "Big Day", detail: "Walk 20,000 steps in one day",
              symbol: "sun.max.fill", xp: 2_000, metric: .bestDaySteps, target: 20_000),
        Badge(id: "thirty-stamps", name: "Thirty Stamps", detail: "Hit your goal on 30 days",
              symbol: "checkmark.seal.fill", xp: 3_000, metric: .goalDays, target: 30),
        Badge(id: "quarter-million", name: "Quarter Million", detail: "Walk 250,000 steps in total",
              symbol: "mountain.2.fill", xp: 3_000, metric: .lifetimeSteps, target: 250_000),
        Badge(id: "month-strong", name: "Month Strong", detail: "Hit your goal 30 days in a row",
              symbol: "trophy.fill", xp: 6_000, metric: .bestStreak, target: 30),
        Badge(id: "millionaire", name: "Millionaire", detail: "Walk 1,000,000 steps in total",
              symbol: "crown.fill", xp: 10_000, metric: .lifetimeSteps, target: 1_000_000),
    ]
}
