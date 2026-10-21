import Foundation

/// A small daily challenge worth bonus XP. Three are picked for each day.
public struct Quest: Identifiable, Hashable {
    public enum Kind: Hashable {
        /// Reach `steps` within a window of the day, in minutes after midnight, or across the whole day.
        case steps(Int, window: ClosedRange<Int>?)
        /// Hit the daily goal before this many minutes after midnight.
        case goalBy(Int)
        /// Walk this multiple of the daily goal.
        case goalMultiple(Double)
        /// Walk more than yesterday (and at least 1,000 steps).
        case beatYesterday
        /// Finish one walk in Walk mode at least this many minutes long.
        case walk(minutes: Int)
    }

    public let id: String
    public let title: String
    public let detail: String
    public let symbol: String
    public let xp: Int
    public let kind: Kind

    /// The part of the day whose steps count, in minutes after midnight, if limited.
    public var window: ClosedRange<Int>? {
        switch kind {
        case .steps(_, let window): return window
        case .goalBy(let minute): return 0...minute
        case .goalMultiple, .beatYesterday, .walk: return nil
        }
    }

    public func target(goal: Int, yesterdaySteps: Int) -> Int {
        switch kind {
        case .steps(let steps, _): return steps
        case .goalBy: return goal
        case .goalMultiple(let multiple): return Int((Double(goal) * multiple).rounded())
        case .beatYesterday: return max(yesterdaySteps + 1, 1_000)
        case .walk(let minutes): return minutes
        }
    }
}

/// What's known about today when checking quests.
public struct QuestContext {
    public var minutesIntoDay: Int
    public var steps: Int
    public var goal: Int
    public var yesterdaySteps: Int
    /// Steps so far inside each windowed quest's window, by quest id.
    public var windowSteps: [String: Int]
    public var longestWalkMinutes: Int

    public init(minutesIntoDay: Int, steps: Int, goal: Int, yesterdaySteps: Int,
                windowSteps: [String: Int], longestWalkMinutes: Int) {
        self.minutesIntoDay = minutesIntoDay
        self.steps = steps
        self.goal = goal
        self.yesterdaySteps = yesterdaySteps
        self.windowSteps = windowSteps
        self.longestWalkMinutes = longestWalkMinutes
    }
}

public enum QuestState: Hashable {
    case done
    case inProgress(current: Int, target: Int)
    /// The quest's window has passed without it being done.
    case missed(current: Int, target: Int)
}

/// Bonus XP awarded on a day, such as for a completed quest.
public struct BonusXP: Codable, Hashable {
    public var day: Day
    public var id: String
    public var xp: Int

    public init(day: Day, id: String, xp: Int) {
        self.day = day
        self.id = id
        self.xp = xp
    }
}

public enum Quests {
    public static let perDay = 3

    public static let all: [Quest] = [
        Quest(id: "early-bird", title: "Early bird", detail: "2,000 steps before 9 AM",
              symbol: "sunrise.fill", xp: 750, kind: .steps(2_000, window: 0...540)),
        Quest(id: "lunch-loop", title: "Lunch loop", detail: "1,500 steps between 11:30 and 2",
              symbol: "fork.knife", xp: 500, kind: .steps(1_500, window: 690...840)),
        Quest(id: "evening-stroll", title: "Evening stroll", detail: "1,500 steps after 7 PM",
              symbol: "moon.stars.fill", xp: 500, kind: .steps(1_500, window: 1_140...1_440)),
        Quest(id: "ahead-of-schedule", title: "Ahead of schedule", detail: "Hit your goal before 6 PM",
              symbol: "clock.badge.checkmark.fill", xp: 1_000, kind: .goalBy(1_080)),
        Quest(id: "overachiever", title: "Overachiever", detail: "Walk 125% of your goal",
              symbol: "chart.line.uptrend.xyaxis", xp: 1_000, kind: .goalMultiple(1.25)),
        Quest(id: "better-than-yesterday", title: "Better than yesterday", detail: "Out-walk yesterday",
              symbol: "arrow.up.right", xp: 750, kind: .beatYesterday),
        Quest(id: "ten-k", title: "10K", detail: "Walk 10,000 steps",
              symbol: "star.fill", xp: 750, kind: .steps(10_000, window: nil)),
        Quest(id: "power-walk", title: "Power walk", detail: "One walk of 15 minutes or more",
              symbol: "figure.walk.motion", xp: 750, kind: .walk(minutes: 15)),
    ]

    /// The same three quests for everyone on a given day, different from day to day.
    public static func forDay(_ day: Day) -> [Quest] {
        var generator = SeededGenerator(seed: UInt64(day.year * 10_000 + day.month * 100 + day.day))
        return Array(all.shuffled(using: &generator).prefix(perDay))
    }

    public static func state(of quest: Quest, in context: QuestContext) -> QuestState {
        let target = quest.target(goal: context.goal, yesterdaySteps: context.yesterdaySteps)
        let current: Int
        switch quest.kind {
        case .walk:
            current = context.longestWalkMinutes
        default:
            current = quest.window == nil ? context.steps : context.windowSteps[quest.id] ?? 0
        }
        if current >= target { return .done }
        if let window = quest.window, context.minutesIntoDay > window.upperBound {
            return .missed(current: current, target: target)
        }
        return .inProgress(current: current, target: target)
    }

    /// The bonus recorded when `quest` is completed on `day`.
    public static func bonus(for quest: Quest, on day: Day) -> BonusXP {
        BonusXP(day: day, id: "quest.\(quest.id)", xp: quest.xp)
    }
}

/// SplitMix64, so the daily pick is the same on every device and every launch.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
