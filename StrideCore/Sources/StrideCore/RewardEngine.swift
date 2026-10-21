import Foundation

public struct RewardInput {
    public var activity: [DayActivity]
    /// Rewards count from this day on. Earlier days show in history but earn nothing.
    public var startDay: Day
    public var today: Day
    public var goalChanges: [GoalChange]
    /// Extra XP, such as from quests.
    public var bonuses: [BonusXP]
    /// Journeys the user has chosen, oldest first. The last one without an end day is in progress.
    public var journeys: [JourneyPlan]

    public init(activity: [DayActivity], startDay: Day, today: Day, goalChanges: [GoalChange],
                bonuses: [BonusXP] = [], journeys: [JourneyPlan] = []) {
        self.activity = activity
        self.startDay = startDay
        self.today = today
        self.goalChanges = goalChanges
        self.bonuses = bonuses
        self.journeys = journeys
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
    /// XP this day earned: steps, the goal bonus and quests.
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
    /// When the journey this stop belongs to was started, so a route walked twice gets new postcards.
    public let journeyStart: Day

    public var id: String { "\(journeyStart.id):\(stop.id)" }
}

/// Progress on one chosen journey.
public struct JourneyProgress: Identifiable, Hashable {
    public let plan: JourneyPlan
    public let kmIntoRoute: Double
    public let completedOn: Day?
    /// Stops reached on this journey, in order.
    public let reached: [ReachedStop]

    public var id: String { "\(plan.route.id):\(plan.startDay.id)" }
    public var route: Route { plan.route }
    public var isComplete: Bool { completedOn != nil }
    public var xp: Int { Journeys.xp(for: plan.route) }

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

    /// Where you are on the map. On a detailed path (a real walking route) it's the same share of
    /// the path's length; on a stop-to-stop path it's between the last stop reached and the next.
    public var coordinate: (latitude: Double, longitude: Double) {
        let stops = route.stops
        let path = route.path
        if path.count > stops.count, path.count > 1 {
            let legs = zip(path, path.dropFirst()).map { $0.km(to: $1) }
            var remaining = legs.reduce(0, +) * routeFraction
            for (index, leg) in legs.enumerated() {
                if remaining <= leg {
                    let fraction = leg > 0 ? remaining / leg : 0
                    let from = path[index], to = path[index + 1]
                    return (from.latitude + (to.latitude - from.latitude) * fraction,
                            from.longitude + (to.longitude - from.longitude) * fraction)
                }
                remaining -= leg
            }
            return (path[path.count - 1].latitude, path[path.count - 1].longitude)
        }
        for (from, to) in zip(stops, stops.dropFirst()) where kmIntoRoute <= to.km {
            let fraction = to.km > from.km ? max(0, kmIntoRoute - from.km) / (to.km - from.km) : 0
            return (from.latitude + (to.latitude - from.latitude) * fraction,
                    from.longitude + (to.longitude - from.longitude) * fraction)
        }
        let last = stops.last
        return (last?.latitude ?? 0, last?.longitude ?? 0)
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
        case quest(BonusXP)
        case journeyComplete(JourneyPlan, Day, xp: Int)
    }

    public let kind: Kind

    public var id: String {
        switch kind {
        case .stamp(let result): return "stamp:\(result.day.id)"
        case .badge(let badge, _): return "badge:\(badge.id)"
        case .stop(let reached): return "stop:\(reached.id)"
        case .freezeUsed(let day): return "freeze:\(day.id)"
        case .levelUp(let level, _): return "level:\(level)"
        case .quest(let bonus): return "bonus:\(bonus.day.id):\(bonus.id)"
        case .journeyComplete(let plan, _, _): return "journey:\(plan.route.id):\(plan.startDay.id)"
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
    /// XP earned day by day: steps, goal bonuses and quests.
    public let stepXP: Int
    public let badgeXP: Int
    /// XP from finished journeys.
    public let journeyXP: Int
    public let badges: [BadgeProgress]
    /// Every chosen journey, oldest first.
    public let journeys: [JourneyProgress]
    /// In the order they were earned.
    public let unlocks: [Unlock]

    private let index: [Day: Int]

    init(today: Day, startDay: Day, goalChanges: [GoalChange], days: [DayResult], currentStreak: Int,
         bestStreak: Int, freezes: Int, lifetimeSteps: Int, lifetimeMeters: Double, stepXP: Int,
         badgeXP: Int, journeyXP: Int, badges: [BadgeProgress], journeys: [JourneyProgress], unlocks: [Unlock]) {
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
        self.journeyXP = journeyXP
        self.badges = badges
        self.journeys = journeys
        self.unlocks = unlocks
        self.index = Dictionary(uniqueKeysWithValues: days.enumerated().map { ($1.day, $0) })
    }

    public var totalXP: Int { stepXP + badgeXP + journeyXP }

    /// The journey being walked: the latest one, unless the user ended it by switching.
    public var journey: JourneyProgress? {
        journeys.last.flatMap { $0.plan.endDay == nil ? $0 : nil }
    }

    /// Every stop reached on every journey, oldest first.
    public var postcards: [ReachedStop] {
        journeys.flatMap(\.reached).sorted { $0.day < $1.day }
    }
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
        let bonusesByDay = Dictionary(grouping: input.bonuses, by: \.day)
        let plans = input.journeys

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
        var journeyXP = 0
        var planMeters = Array(repeating: 0.0, count: plans.count)
        var planReached = Array(repeating: [ReachedStop](), count: plans.count)
        var planCompleted = Array(repeating: Day?.none, count: plans.count)

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

            let dayBonuses = bonusesByDay[day] ?? []
            let xp = steps * RewardRules.xpPerStep + (met ? RewardRules.goalBonusXP : 0)
                + dayBonuses.reduce(0) { $0 + $1.xp }
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
            unlocks.append(contentsOf: dayBonuses.map { Unlock(kind: .quest($0)) })

            for badge in Badges.all where badgeUnlocks[badge.id] == nil && value(of: badge.metric) >= badge.target {
                badgeUnlocks[badge.id] = day
                badgeXP += badge.xp
                unlocks.append(Unlock(kind: .badge(badge, day)))
            }

            for (index, plan) in plans.enumerated() where planCompleted[index] == nil && day >= plan.startDay {
                if let end = plan.endDay, day > end { continue }
                planMeters[index] += meters
                let km = planMeters[index] / 1000
                for stop in plan.route.stops where km >= stop.km && !planReached[index].contains(where: { $0.stop.id == stop.id }) {
                    let reached = ReachedStop(route: plan.route, stop: stop, day: day, journeyStart: plan.startDay)
                    planReached[index].append(reached)
                    unlocks.append(Unlock(kind: .stop(reached)))
                }
                if km >= plan.route.lengthKm {
                    planCompleted[index] = day
                    let xp = Journeys.xp(for: plan.route)
                    journeyXP += xp
                    unlocks.append(Unlock(kind: .journeyComplete(plan, day, xp: xp)))
                }
            }

            let newLevel = Levels.level(forXP: stepXP + badgeXP + journeyXP)
            if newLevel > level {
                for levelReached in (level + 1)...newLevel {
                    unlocks.append(Unlock(kind: .levelUp(levelReached, day)))
                }
                level = newLevel
            }
        }

        let badges = Badges.all.map {
            BadgeProgress(badge: $0, value: value(of: $0.metric), unlockedOn: badgeUnlocks[$0.id])
        }

        let journeys = plans.indices.map { index in
            JourneyProgress(plan: plans[index], kmIntoRoute: min(planMeters[index] / 1000, plans[index].route.lengthKm),
                            completedOn: planCompleted[index], reached: planReached[index])
        }

        return RewardSummary(
            today: today, startDay: start, goalChanges: input.goalChanges, days: days,
            currentStreak: streak, bestStreak: bestStreak, freezes: freezes,
            lifetimeSteps: lifetimeSteps, lifetimeMeters: lifetimeMeters,
            stepXP: stepXP, badgeXP: badgeXP, journeyXP: journeyXP,
            badges: badges, journeys: journeys, unlocks: unlocks)
    }

    static func effectiveMeters(steps: Int, meters: Double) -> Double {
        meters > 0 ? meters : Double(steps) * RewardRules.fallbackStrideMeters
    }
}
