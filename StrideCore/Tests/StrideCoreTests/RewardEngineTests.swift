import XCTest
@testable import StrideCore

final class RewardEngineTests: XCTestCase {
    let start = Day(year: 2026, month: 10, day: 1)

    private func summarize(_ steps: [Int], goal: Int = 8_000, startOffset: Int = 0) -> RewardSummary {
        let activity = steps.enumerated().map { offset, count in
            DayActivity(day: start.adding(days: offset), steps: count, meters: 0)
        }
        return RewardEngine.summarize(RewardInput(
            activity: activity,
            startDay: start.adding(days: startOffset),
            today: start.adding(days: steps.count - 1),
            goalChanges: [GoalChange(from: start, goal: goal)]))
    }

    func testDayArithmetic() {
        let day = Day(year: 2026, month: 2, day: 28)
        XCTAssertEqual(day.adding(days: 1), Day(year: 2026, month: 3, day: 1))
        XCTAssertEqual(day.adding(days: -59), Day(year: 2025, month: 12, day: 31))
        XCTAssertEqual(day.days(until: Day(year: 2026, month: 3, day: 2)), 2)
        XCTAssertEqual(Day(year: 2026, month: 12, day: 30).through(Day(year: 2027, month: 1, day: 2)).count, 4)
        XCTAssertEqual(Day(id: "2026-10-05"), Day(year: 2026, month: 10, day: 5))
        XCTAssertEqual(Day(year: 2026, month: 10, day: 5).id, "2026-10-05")
    }

    func testDayRoundTripsThroughJSON() throws {
        let day = Day(year: 2026, month: 1, day: 9)
        let data = try JSONEncoder().encode([day])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-01-09\"]")
        XCTAssertEqual(try JSONDecoder().decode([Day].self, from: data), [day])
    }

    func testXPIsOnePerStepPlusGoalBonus() {
        let summary = summarize([8_050, 4_999])
        XCTAssertEqual(summary.days[0].xp, 8_050 + RewardRules.goalBonusXP)
        XCTAssertEqual(summary.days[1].xp, 4_999)
        XCTAssertEqual(summary.stepXP, 8_050 + 1_500 + 4_999)
    }

    func testDaysBeforeStartEarnNothing() {
        let summary = summarize([12_000, 12_000, 3_000], startOffset: 2)
        XCTAssertEqual(summary.days.map(\.status), [.beforeStart, .beforeStart, .inProgress])
        XCTAssertEqual(summary.stepXP, 3_000)
        XCTAssertEqual(summary.lifetimeSteps, 3_000)
        XCTAssertEqual(summary.currentStreak, 0)
    }

    func testTodayInProgressDoesNotBreakStreak() {
        let summary = summarize([9_000, 9_000, 2_000])
        XCTAssertEqual(summary.currentStreak, 2)
        XCTAssertEqual(summary.todayResult.status, .inProgress)
    }

    func testMissedDayResetsStreakWithoutFreeze() {
        let summary = summarize([9_000, 9_000, 1_000, 9_000])
        XCTAssertEqual(summary.days.map(\.status), [.met, .met, .missed, .met])
        XCTAssertEqual(summary.currentStreak, 1)
        XCTAssertEqual(summary.bestStreak, 2)
    }

    func testSevenDayStreakEarnsAFreezeThatSavesTheNextMiss() {
        let week = Array(repeating: 9_000, count: 7)
        let summary = summarize(week + [500, 9_000])
        XCTAssertEqual(summary.days[7].status, .frozen)
        XCTAssertEqual(summary.currentStreak, 8)
        XCTAssertEqual(summary.freezes, 0)
        XCTAssertTrue(summary.unlocks.contains { $0.id == "freeze:\(start.adding(days: 7).id)" })
    }

    func testFreezesCapAtMax() {
        let summary = summarize(Array(repeating: 9_000, count: 28))
        XCTAssertEqual(summary.freezes, RewardRules.maxFreezes)
    }

    func testGoalChangesApplyFromTheirDay() {
        let changes = [GoalChange(from: start, goal: 8_000), GoalChange(from: start.adding(days: 2), goal: 10_000)]
        XCTAssertEqual(RewardEngine.goal(for: start.adding(days: -5), changes: changes), 8_000)
        XCTAssertEqual(RewardEngine.goal(for: start.adding(days: 1), changes: changes), 8_000)
        XCTAssertEqual(RewardEngine.goal(for: start.adding(days: 2), changes: changes), 10_000)
        XCTAssertEqual(RewardEngine.goal(for: start.adding(days: 30), changes: changes), 10_000)
        XCTAssertEqual(RewardEngine.goal(for: start, changes: []), RewardRules.defaultGoal)
    }

    func testBadgesUnlockOnTheDayTheyAreEarnedAndGiveXP() {
        let summary = summarize([3_000, 10_500])
        let unlocked = Dictionary(uniqueKeysWithValues: summary.badges.map { ($0.badge.id, $0.unlockedOn) })
        XCTAssertEqual(unlocked["first-steps"], start)
        XCTAssertEqual(unlocked["goal-getter"], start.adding(days: 1))
        XCTAssertEqual(unlocked["10k-club"], start.adding(days: 1))
        XCTAssertEqual(unlocked["hat-trick"], .some(nil))
        XCTAssertEqual(summary.badgeXP, 200 + 500 + 1_000)
        XCTAssertEqual(summary.totalXP, summary.stepXP + summary.badgeXP)
    }

    func testLevelThresholds() {
        XCTAssertEqual(Levels.xpRequired(for: 1), 0)
        XCTAssertEqual(Levels.xpRequired(for: 2), 2_000)
        XCTAssertEqual(Levels.xpRequired(for: 6), 50_000)
        XCTAssertEqual(Levels.level(forXP: 0), 1)
        XCTAssertEqual(Levels.level(forXP: 1_999), 1)
        XCTAssertEqual(Levels.level(forXP: 2_000), 2)
        XCTAssertEqual(Levels.level(forXP: 50_000), 6)
        XCTAssertEqual(Levels.level(forXP: 100_000_000), Levels.maxLevel)
    }

    func testTiersCoverFiveLevelsEach() {
        XCTAssertEqual(Levels.tiers.count, 10)
        XCTAssertEqual(Levels.tier(forLevel: 1).number, 1)
        XCTAssertEqual(Levels.tier(forLevel: 5).number, 1)
        XCTAssertEqual(Levels.tier(forLevel: 6).number, 2)
        XCTAssertEqual(Levels.tier(forLevel: 50).number, 10)
        XCTAssertEqual(Levels.tiers[1].firstLevel, 6)
        XCTAssertEqual(Levels.tiers[1].lastLevel, 10)
    }

    func testLevelProgress() {
        let progress = LevelProgress(xp: 5_000)
        XCTAssertEqual(progress.level, 2)
        XCTAssertEqual(progress.xpIntoLevel, 3_000)
        XCTAssertEqual(progress.xpForLevel, 6_000)
        XCTAssertEqual(progress.xpToNextLevel, 3_000)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(progress.nextTier?.tier.number, 2)
        XCTAssertEqual(progress.nextTier?.xpNeeded, 45_000)

        let maxed = LevelProgress(xp: 100_000_000)
        XCTAssertTrue(maxed.isMaxLevel)
        XCTAssertEqual(maxed.fraction, 1)
        XCTAssertNil(maxed.nextTier)
    }

    func testLevelUpsAreUnlockedOnTheDayTheyHappen() {
        // Day 0: 3,000 steps + 200 badge XP = 3,200 XP, level 2.
        // Day 1: +9,000 steps + 1,500 goal bonus + 500 + 0 badge XP = 14,200 XP, level 3.
        let summary = summarize([3_000, 9_000])
        let levelUps = summary.unlocks.compactMap { unlock -> (Int, Day)? in
            if case .levelUp(let level, let day) = unlock.kind { return (level, day) }
            return nil
        }
        XCTAssertEqual(levelUps.map { $0.0 }, [2, 3])
        XCTAssertEqual(levelUps.map { $0.1 }, [start, start.adding(days: 1)])
        XCTAssertEqual(summary.level.level, 3)
    }

    func testJourneyReachesStopsAndMovesToTheNextRoute() {
        // 44 km is past the end of the Inca Trail (43 km) and 1 km into Hadrian's Wall.
        let activity = [DayActivity(day: start, steps: 50_000, meters: 44_000)]
        let summary = RewardEngine.summarize(RewardInput(
            activity: activity, startDay: start, today: start,
            goalChanges: [GoalChange(from: start, goal: 8_000)]))
        let journey = summary.journey
        XCTAssertEqual(journey.route.id, "hadrian")
        XCTAssertEqual(journey.kmIntoRoute, 1, accuracy: 0.001)
        XCTAssertEqual(journey.nextStop?.id, "hadrian.newcastle")
        XCTAssertEqual(journey.reached.map(\.stop.id).suffix(2), ["inca.machupicchu", "hadrian.wallsend"])
        XCTAssertFalse(journey.isComplete)
    }

    func testMissingDistanceFallsBackToStride() {
        let summary = summarize([10_000])
        XCTAssertEqual(summary.lifetimeMeters, 10_000 * RewardRules.fallbackStrideMeters, accuracy: 0.001)
    }

    func testLastDaysPadsMissingDays() {
        let summary = summarize([5_000, 6_000])
        let week = summary.lastDays(7)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.last?.steps, 6_000)
        XCTAssertEqual(week.first?.steps, 0)
        XCTAssertEqual(week.first?.status, .beforeStart)
    }

    func testBonusXPCountsOnItsDay() {
        let bonus = BonusXP(day: start, id: "quest.ten-k", xp: 750)
        let summary = RewardEngine.summarize(RewardInput(
            activity: [DayActivity(day: start, steps: 3_000, meters: 0)], startDay: start, today: start,
            goalChanges: [GoalChange(from: start, goal: 8_000)], bonuses: [bonus]))
        XCTAssertEqual(summary.todayResult.xp, 3_000 + 750)
        XCTAssertTrue(summary.unlocks.contains { $0.id == "bonus:\(start.id):quest.ten-k" })
    }

    func testQuestsAreThreeDistinctAndStableForADay() {
        let quests = Quests.forDay(start)
        XCTAssertEqual(quests.count, Quests.perDay)
        XCTAssertEqual(Set(quests.map(\.id)).count, Quests.perDay)
        XCTAssertEqual(Quests.forDay(start).map(\.id), quests.map(\.id))
        let week = start.through(start.adding(days: 6)).map { Quests.forDay($0).map(\.id) }
        XCTAssertGreaterThan(Set(week).count, 1)
    }

    func testQuestStates() {
        let earlyBird = Quests.all.first { $0.id == "early-bird" }!
        var context = QuestContext(minutesIntoDay: 480, steps: 1_500, goal: 8_000, yesterdaySteps: 6_000,
                                   windowSteps: ["early-bird": 1_500], longestWalkMinutes: 0)
        XCTAssertEqual(Quests.state(of: earlyBird, in: context), .inProgress(current: 1_500, target: 2_000))
        context.minutesIntoDay = 600
        XCTAssertEqual(Quests.state(of: earlyBird, in: context), .missed(current: 1_500, target: 2_000))
        context.windowSteps["early-bird"] = 2_100
        XCTAssertEqual(Quests.state(of: earlyBird, in: context), .done)

        let beat = Quests.all.first { $0.id == "better-than-yesterday" }!
        XCTAssertEqual(Quests.state(of: beat, in: context), .inProgress(current: 1_500, target: 6_001))

        let walk = Quests.all.first { $0.id == "power-walk" }!
        context.longestWalkMinutes = 16
        XCTAssertEqual(Quests.state(of: walk, in: context), .done)
    }

    func testRouteStopsAreInOrder() {
        for route in Journeys.routes {
            XCTAssertEqual(route.stops.first?.km, 0, route.name)
            XCTAssertEqual(route.stops.map(\.km), route.stops.map(\.km).sorted(), route.name)
        }
        XCTAssertEqual(Set(Journeys.milestones.map(\.stop.id)).count, Journeys.milestones.count)
    }
}
