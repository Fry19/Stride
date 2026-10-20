import Foundation
import Observation
import StrideCore

@MainActor
@Observable
final class AppModel {
    private(set) var state: SavedState
    private(set) var summary: RewardSummary
    /// Newly earned stamps, badges and postcards waiting to be shown.
    private(set) var celebration: [Unlock] = []
    private(set) var isRefreshing = false
    private(set) var healthError: String?

    @ObservationIgnored private let health = HealthSource()
    @ObservationIgnored private let motion = MotionSource()
    @ObservationIgnored private var liveDay: Day?

    init() {
        let state = StateStore.load() ?? SavedState(startDay: Day(Date()))
        self.state = state
        self.summary = Self.makeSummary(for: state, today: Day(Date()))
    }

    /// Today's goal.
    var goal: Int {
        RewardEngine.goal(for: Day(Date()), changes: state.goalChanges)
    }

    // MARK: - Steps

    func completeOnboarding(goal: Int) async {
        setGoal(goal)
        do {
            try await health.requestAccess()
        } catch {
            healthError = error.localizedDescription
        }
        // Asks for Motion & Fitness access, used for live updates.
        _ = await motion.dailyTotals(lastDays: 1, endingOn: Day(Date()))
        state.startDay = Day(Date())
        state.hasOnboarded = true
        save()
        await refresh()
    }

    func refresh() async {
        guard state.hasOnboarded, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let today = Day(Date())
        var fetched: [DayActivity] = []
        do {
            fetched += try await health.dailyTotals(from: min(state.startDay, today.adding(days: -27)), through: today)
            healthError = nil
        } catch {
            healthError = error.localizedDescription
        }
        fetched += await motion.dailyTotals(lastDays: 7, endingOn: today)
        merge(fetched)
        save()
        recompute()
        startLiveUpdates()
    }

    func startLiveUpdates() {
        let today = Day(Date())
        guard state.hasOnboarded, liveDay != today else { return }
        motion.stopLiveUpdates()
        liveDay = today
        motion.startLiveUpdates(for: today) { [weak self] activity in
            Task { @MainActor in self?.applyLiveUpdate(activity) }
        }
    }

    func stopLiveUpdates() {
        motion.stopLiveUpdates()
        liveDay = nil
    }

    private func applyLiveUpdate(_ activity: DayActivity) {
        guard activity.day == Day(Date()) else {
            // Midnight passed while the app was open; start counting the new day.
            Task { await refresh() }
            return
        }
        merge([activity])
        recompute()
    }

    /// Keeps the higher count for each day, so data from either source is never lost.
    private func merge(_ fetched: [DayActivity]) {
        var byDay = Dictionary(state.activity.map { ($0.day, $0) }) { first, _ in first }
        for item in fetched {
            let existing = byDay[item.day]
            byDay[item.day] = DayActivity(
                day: item.day,
                steps: max(item.steps, existing?.steps ?? 0),
                meters: max(item.meters, existing?.meters ?? 0))
        }
        state.activity = byDay.values.sorted { $0.day < $1.day }
    }

    // MARK: - Settings and rewards

    func setGoal(_ goal: Int) {
        let today = Day(Date())
        state.goalChanges.removeAll { $0.from == today }
        state.goalChanges.append(GoalChange(from: today, goal: goal))
        save()
        recompute()
    }

    func addReward(name: String, cost: Int) {
        state.rewards.append(Reward(name: name, cost: cost))
        save()
    }

    func deleteReward(_ reward: Reward) {
        state.rewards.removeAll { $0.id == reward.id }
        save()
    }

    func canRedeem(_ reward: Reward) -> Bool {
        !state.useSampleData && summary.balance >= reward.cost
    }

    @discardableResult
    func redeem(_ reward: Reward) -> Bool {
        guard canRedeem(reward) else { return false }
        state.redemptions.append(Redemption(rewardName: reward.name, cost: reward.cost, date: Date()))
        save()
        recompute()
        return true
    }

    func setUseSampleData(_ on: Bool) {
        state.useSampleData = on
        save()
        recompute()
    }

    func finishCelebration() {
        state.celebrated.formUnion(celebration.map(\.id))
        celebration = []
        save()
    }

    func save() {
        StateStore.save(state)
    }

    // MARK: - Rewards

    private func recompute() {
        summary = Self.makeSummary(for: state, today: Day(Date()))
        guard state.hasOnboarded, !state.useSampleData else { return }
        let showing = Set(celebration.map(\.id))
        let fresh = summary.unlocks.filter { !state.celebrated.contains($0.id) && !showing.contains($0.id) }
        celebration.append(contentsOf: fresh)
    }

    private static func makeSummary(for state: SavedState, today: Day) -> RewardSummary {
        if state.useSampleData {
            let sample = SampleData.activity(endingOn: today)
            return RewardEngine.summarize(RewardInput(
                activity: sample.activity, startDay: sample.startDay, today: today,
                goalChanges: state.goalChanges, redemptions: []))
        }
        return RewardEngine.summarize(RewardInput(
            activity: state.activity, startDay: state.startDay, today: today,
            goalChanges: state.goalChanges, redemptions: state.redemptions))
    }
}
