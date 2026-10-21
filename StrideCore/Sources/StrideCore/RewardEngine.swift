import Foundation

public struct RewardInput {
    public var activity: [DayActivity]
    /// Rewards count from this day on. Earlier days show in history but earn nothing.
    public var startDay: Day
    public var today: Day
    public var goalChanges: [GoalChange]

    public init(activity: [DayActivity], startDay: Day, today: Day, goalChanges: [GoalChange]) {
        self.activity = activity
        self.startDay = startDay
        self.today = today
        self.goalChanges = goalChanges
    }
}

public enum DayStatus: Hashable {
    case met
    /// Goal missed, but a streak freeze kept the streak alive.
    case frozen
    case missed
    /// Today, goal not met yet.
    case inProgress
    /// Before the user started Stride.
    case beforeStart
}

public struct DayResult: Hashable, Identifiable {
    public let day: Day
    public let steps: Int
    public let meters: Double
    public let goal: Int
    public let status: DayStatus
    /// XP this day earned, including the goal bonus.
    public let xp: Int

    public var id: Day { day }
    public var goalMet: Bool { steps >= goal }
}

public struct BadgeProgress: Identifiable, Hashable {
    public let badge: Badge
    /// Current value of the badge's metric.
    public let value: Double
    public let unlockedOn: Day?

    public var id: String { badge.id }
    public var isUnlocked: Bool { unlockedOn != nil }
    public var fraction: Double { min(1, value / badge.target) }
}

public struct ReachedStop: Identifiable, Hashable {
    public let route: Route
    public let stop: Stop
    public let day: Day

    public var id: String { stop.id }
}

public struct JourneyProgress: Hashable {
    /// The route being walked, or the last route once every route is finished.
    public let route: Route
    public let kmIntoRoute: Double
    public let totalKm: Double
    public let isComplete: Bool
    /// Every stop reached so far, in the order reached.
    public let reached: [ReachedStop]

    public var nextStop: Stop? {
        isComplete ? nil : route.stops.first { $0.km > kmIntoRoute }
    }

    public var kmToNextStop: Double? {
        nextStop.map { $0.km - kmIntoRoute }
    }

    public var routeFraction: Double {
        route.lengthKm > 0 ? min(1, kmIntoRoute / route.lengthKm) : 1
    }

    public func reachedStop(_ stop: Stop) -> ReachedStop? {
        reached.first { $0.stop.id == stop.id }
    }
}

/// Something newly earned, for the celebration screen. `id` is stable so the app
/// can remember which unlocks it has already shown.
public struct Unlock: Identifiable, Hashable {
    public enum Kind: Hashable {
        case stamp(DayResult)
        case badge(Badge, Day)
        case stop(ReachedStop)
        case freezeUsed(Day)
        case levelUp(Int, Day)
    }

    public let kind: Kind

    public var id: String {
        switch kind {
        case .stamp(let result): return "stamp:\(result.day.id)"
        case .badge(let badge, _): return "badge:\(badge.id)"
        case .stop(let reached): return "stop:\(reached.stop.id)"
        case .freezeUsed(let day): return "freeze:\(day.id)"
        case .levelUp(let level, _): return "level:\(level)"
        }
    }
}

public struct RewardSummary {
    public let today: Day
    public let startDay: Day
    public let goalChanges: [GoalChange]
    /// Oldest first, through today.
    public let days: [DayResult]
    public let currentStreak: Int
    public let bestStreak: Int
    public let freezes: Int
    /// Since the start day.
    public let lifetimeSteps: Int
    public let lifetimeMeters: Double
    /// XP from steps and goal bonuses.
    public let stepXP: Int
    public let badgeXP: Int
    public let badges: [BadgeProgress]
    public let journey: JourneyProgress
    /// In the order they were earned.
    public let unlocks: [Unlock]

    private let index: [Day: Int]

    init(today: Day, startDay: Day, goalChanges: [GoalChange], days: [DayResult], currentStreak: Int,
         bestStreak: Int, freezes: Int, lifetimeSteps: Int, lifetimeMeters: Double, stepXP: Int,
         badgeXP: Int, badges: [BadgeProgress], journey: JourneyProgress, unlocks: [Unlock]) {
        self.today = today
        self.startDay = startDay
        self.goalChanges = goalChanges
        self.days = days
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.freezes = freezes
        self.lifetimeSteps = lifetimeSteps
        self.lifetimeMeters = lifetimeMeters
        self.stepXP = stepXP
        self.badgeXP = badgeXP
        self.badges = badges
        self.journey = journey
        self.unlocks = unlocks
        self.index = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($1.day, $0) })
    }

    public var totalXP: Int { stepXP + badgeXP }
    public var level: LevelProgress { LevelProgress(xp: totalXP) }

    public var todayResult: DayResult {
        result(for: today) ?? emptyResult(for: today)
    }

    /// Days the goal was met since the start day, newest first.
    public var stamps: [DayResult] {
        days.filter { $0.status == .met }.reversed()
    }

    public func result(for day: Day) -> DayResult? {
        index[day].map { days[$0] }
    }

    /// The last `count` days ending today, oldest first, including days with no data.
    public func lastDays(_ count: Int) -> [DayResult] {
        today.adding(days: -(count - 1)).through(today).map { result(for: $0) ?? emptyResult(for: $0) }
    }

    private func emptyResult(for day: Day) -> DayResult {
        DayResult(day: day, steps: 0, meters: 0, goal: RewardEngine.goal(for: day, changes: goalChanges),
                  status: day < startDay ? .beforeStart : .inProgress, xp: 0)
    }
}

public enum RewardEngine {
    /// The goal in force on `day`. Days before the first change use the first goal.
    public static func goal(for day: Day, changes: [GoalChange]) -> Int {
        if let current = changes.filter({ $0.from <= day }).max(by: { $0.from < $1.from }) {
            return current.goal
        }
        return changes.min(by: { $0.from < $1.from })?.goal ?? RewardRules.defaultGoal
    }

    public static func summarize(_ input: RewardInput) -> RewardSummary {
        let today = input.today
        let start = min(input.startDay, today)
        let byDay = Dictionary(input.activity.map { ($0.day, $0) }) { first, second in
            first.steps >= second.steps ? first : second
        }
        let earliest = byDay.keys.filter { $0 <= today }.min() ?? start
        let milestones = Journeys.milestones

        var days: [DayResult] = []
        var unlocks: [Unlock] = []
        var streak = 0
        var bestStreak = 0
        var freezes = 0
        var stepXP = 0
        var lifetimeSteps = 0
        var lifetimeMeters = 0.0
        var daysWalked = 0
        var goalDays = 0
        var bestDaySteps = 0
        var badgeUnlocks: [String: Day] = [:]
        var badgeXP = 0
        var level = 1
        var reached: [ReachedStop] = []
        var nextMilestone = 0

        func value(of metric: Badge.Metric) -> Double {
            switch metric {
            case .daysWalked: return Double(daysWalked)
            case .goalDays: return Double(goalDays)
            case .bestDaySteps: return Double(bestDaySteps)
            case .bestStreak: return Double(bestStreak)
            case .lifetimeSteps: return Double(lifetimeSteps)
            case .lifetimeMeters: return lifetimeMeters
            }
        }

        for day in min(earliest, start).through(today) {
            let activity = byDay[day]
            let steps = max(0, activity?.steps ?? 0)
            let meters = effectiveMeters(steps: steps, meters: activity?.meters ?? 0)
            let dayGoal = Self.goal(for: day, changes: input.goalChanges)

            guard day >= start else {
                days.append(DayResult(day: day, steps: steps, meters: meters, goal: dayGoal, status: .beforeStart, xp: 0))
                continue
            }

            let met = steps >= dayGoal
            let status: DayStatus
            if met {
                streak += 1
                bestStreak = max(bestStreak, streak)
                if streak % RewardRules.streakDaysPerFreeze == 0 {
                    freezes = min(freezes + 1, RewardRules.maxFreezes)
                }
                status = .met
            } else if day == today {
                // Today isn't over, so it can't break the streak yet.
                status = .inProgress
            } else if streak > 0 && freezes > 0 {
                freezes -= 1
                status = .frozen
            } else {
                streak = 0
                status = .missed
            }

            let xp = steps * RewardRules.xpPerStep + (met ? RewardRules.goalBonusXP : 0)
            stepXP += xp
            lifetimeSteps += steps
            lifetimeMeters += meters
            if steps > 0 { daysWalked += 1 }
            if met { goalDays += 1 }
            bestDaySteps = max(bestDaySteps, steps)

            let result = DayResult(day: day, steps: steps, meters: meters, goal: dayGoal, status: status, xp: xp)
            days.append(result)
            if met { unlocks.append(Unlock(kind: .stamp(result))) }
            if status == .frozen { unlocks.append(Unlock(kind: .freezeUsed(day))) }

            for badge in Badges.all where badgeUnlocks[badge.id] == nil && value(of: badge.metric) >= badge.target {
                badgeUnlocks[badge.id] = day
                badgeXP += badge.xp
                unlocks.append(Unlock(kind: .badge(badge, day)))
            }

            let newLevel = Levels.level(forXP: stepXP + badgeXP)
            if newLevel > level {
                for levelReached in (level + 1)...newLevel {
                    unlocks.append(Unlock(kind: .levelUp(levelReached, day)))
                }
                level = newLevel
            }

            let km = lifetimeMeters / 1000
            while nextMilestone < milestones.count && km >= milestones[nextMilestone].totalKm {
                let milestone = milestones[nextMilestone]
                let stop = ReachedStop(route: milestone.route, stop: milestone.stop, day: day)
                reached.append(stop)
                unlocks.append(Unlock(kind: .stop(stop)))
                nextMilestone += 1
            }
        }

        let badges = Badges.all.map {
            BadgeProgress(badge: $0, value: value(of: $0.metric), unlockedOn: badgeUnlocks[$0.id])
        }

        return RewardSummary(
            today: today, startDay: start, goalChanges: input.goalChanges, days: days,
            currentStreak: streak, bestStreak: bestStreak, freezes: freezes,
            lifetimeSteps: lifetimeSteps, lifetimeMeters: lifetimeMeters,
            stepXP: stepXP, badgeXP: badgeXP,
            badges: badges, journey: journeyProgress(totalKm: lifetimeMeters / 1000, reached: reached),
            unlocks: unlocks)
    }

    static func effectiveMeters(steps: Int, meters: Double) -> Double {
        meters > 0 ? meters : Double(steps) * RewardRules.fallbackStrideMeters
    }

    static func journeyProgress(totalKm: Double, reached: [ReachedStop]) -> JourneyProgress {
        for route in Journeys.routes {
            let start = Journeys.startKm(of: route)
            if totalKm < start + route.lengthKm {
                return JourneyProgress(route: route, kmIntoRoute: max(0, totalKm - start), totalKm: totalKm,
                                       isComplete: false, reached: reached)
            }
        }
        let last = Journeys.routes[Journeys.routes.count - 1]
        return JourneyProgress(route: last, kmIntoRoute: last.lengthKm, totalKm: totalKm, isComplete: true, reached: reached)
    }
}
