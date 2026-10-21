import Foundation

/// Steps and distance walked on one day.
public struct DayActivity: Codable, Hashable {
    public var day: Day
    public var steps: Int
    public var meters: Double

    public init(day: Day, steps: Int, meters: Double) {
        self.day = day
        self.steps = steps
        self.meters = meters
    }
}

/// A daily step goal that applies from `from` until the next change.
public struct GoalChange: Codable, Hashable {
    public var from: Day
    public var goal: Int

    public init(from: Day, goal: Int) {
        self.from = from
        self.goal = goal
    }
}

public enum RewardRules {
    /// XP for each step.
    public static let xpPerStep = 1
    /// Extra XP for hitting the daily goal.
    public static let goalBonusXP = 1_500
    /// A streak freeze is earned each time a streak reaches a multiple of this.
    public static let streakDaysPerFreeze = 7
    /// Most freezes that can be saved up.
    public static let maxFreezes = 2
    public static let defaultGoal = 8_000
    /// Used for days with steps but no recorded distance.
    public static let fallbackStrideMeters = 0.75
}
