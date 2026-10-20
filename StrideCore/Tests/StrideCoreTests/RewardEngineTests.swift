import XCTest
@testable import StrideCore

final class RewardEngineTests: XCTestCase {
    let start = Day(year: 2026, month: 10, day: 1)

    private func summarize(_ steps: [Int], goal: Int = 8_000, startOffset: Int = 0,
                           redemptions: [Redemption] = []) -> RewardSummary {
        let activity = steps.enumerated().map { offset, count in
            DayActivity(day: start.adding(days: offset), steps: count, meters: 0)
        }
        return RewardEngine.summarize(RewardInput(
            activity: activity,
            startDay: start.adding(days: startOffset),
            today: start.adding(days: steps.count - 1),
            goalChanges: [GoalChange(from: start, goal: goal)],
            redemptions: redemptions))
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

    func testCoinsAreOnePer100StepsPlusGoalBonus() {
        let summary = summarize([8_050, 4_999])
        XCTAssertEqual(summary.days[0].coins, 80 + RewardRules.goalBonus)
        XCTAssertEqual(summary.days[1].coins, 49)
        XCTAssertEqual(summary.stepCoins, 80 + 25 + 49)
    }

    func testDaysBeforeStartEarnNothing() {
        let summary = summarize([12_000, 12_000, 3_000], startOffset: 2)
        XCTAssertEqual(summary.days.map(\.status), [.beforeStart, .beforeStart, .inProgress])
        XCTAssertEqual(summary.stepCoins, 30)
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

    func testBadgesUnlockOnTheDayTheyAreEarnedAndPayABonus() {
        let summary = summarize([3_000, 10_500])
        let unlocked = Dictionary(uniqueKeysWithValues: summary.badges.map { ($0.badge.id, $0.unlockedOn) })
        XCTAssertEqual(unlocked["first-steps"], start)
        XCTAssertEqual(unlocked["goal-getter"], start.adding(days: 1))
        XCTAssertEqual(unlocked["10k-club"], start.adding(days: 1))
        XCTAssertEqual(unlocked["hat-trick"], .some(nil))
        XCTAssertEqual(summary.badgeCoins, 10 + 25 + 50)
    }

    func testBalanceSubtractsRedemptions() {
        let spend = Redemption(rewardName: "Coffee", cost: 100, date: Date())
        let summary = summarize([20_000], redemptions: [spend])
        XCTAssertEqual(summary.spentCoins, 100)
        XCTAssertEqual(summary.balance, summary.stepCoins + summary.badgeCoins - 100)
    }

    func testJourneyReachesStopsAndMovesToTheNextRoute() {
        // 44 km is past the end of the Inca Trail (43 km) and 1 km into Hadrian's Wall.
        let activity = [DayActivity(day: start, steps: 50_000, meters: 44_000)]
        let summary = RewardEngine.summarize(RewardInput(
            activity: activity, startDay: start, today: start,
            goalChanges: [GoalChange(from: start, goal: 8_000)], redemptions: []))
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

    func testRouteStopsAreInOrder() {
        for route in Journeys.routes {
            XCTAssertEqual(route.stops.first?.km, 0, route.name)
            XCTAssertEqual(route.stops.map(\.km), route.stops.map(\.km).sorted(), route.name)
        }
        XCTAssertEqual(Set(Journeys.milestones.map(\.stop.id)).count, Journeys.milestones.count)
    }
}
