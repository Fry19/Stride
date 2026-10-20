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

/// A real-life treat the user sets a coin price on.
public struct Reward: Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var cost: Int

    public init(id: UUID = UUID(), name: String, cost: Int) {
        self.id = id
        self.name = name
        self.cost = cost
    }
}

/// Coins spent on a reward.
public struct Redemption: Codable, Hashable, Identifiable {
    public var id: UUID
    public var rewardName: String
    public var cost: Int
    public var date: Date

    public init(id: UUID = UUID(), rewardName: String, cost: Int, date: Date) {
        self.id = id
        self.rewardName = rewardName
        self.cost = cost
        self.date = date
    }
}

public enum RewardRules {
    /// One coin for every this many steps.
    public static let stepsPerCoin = 100
    /// Extra coins for hitting the daily goal.
    public static let goalBonus = 25
    /// A streak freeze is earned each time a streak reaches a multiple of this.
    public static let streakDaysPerFreeze = 7
    /// Most freezes that can be saved up.
    public static let maxFreezes = 2
    public static let defaultGoal = 8_000
    /// Used for days with steps but no recorded distance.
    public static let fallbackStrideMeters = 0.75
}
