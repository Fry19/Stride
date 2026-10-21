import Foundation
import Observation
import StrideCore

@MainActor
@Observable
final class AppModel {
    private(set) var state: SavedState
    private(set) var summary: RewardSummary
    /// Newly earned levels, stamps, badges and postcards waiting to be shown.
    private(set) var celebration: [Unlock] = []
    private(set) var isRefreshing = false
    private(set) var healthError: String?
    /// When today's count last went up while the app was open.
    private(set) var lastLiveStep: Date?
    /// Today against yesterday and the best day this week, at the same time of day.
    private(set) var race: RaceStatus?
    /// Today's quests and how far along each one is.
    private(set) var quests: [QuestProgress] = []

    @ObservationIgnored private let health = HealthSource()
    @ObservationIgnored private let motion = MotionSource()
    @ObservationIgnored private let detector = StepDetector()
    @ObservationIgnored private var liveDay: Day?
    /// Today's total at the pedometer's last report, and steps the detector has counted since.
    @ObservationIgnored private var pedometerSteps = 0
    @ObservationIgnored private var detectedSincePedometer = 0
    @ObservationIgnored private var metersPerStep = RewardRules.fallbackStrideMeters
    /// Today's count including detected steps. Shown but never saved, since the pedometer
    /// and Health have the final word.
    @ObservationIgnored private var liveEstimate: DayActivity?
    @ObservationIgnored private var raceRefreshedAt: Date?
    /// Steps so far inside each of today's windowed quests, by quest id.
    @ObservationIgnored private var questWindowSteps: [String: Int] = [:]

    init() {
        let today = Day(Date())
        let state = ScreenshotMode.isActive
            ? ScreenshotMode.state(today: today)
            : StateStore.load() ?? SavedState(startDay: today)
        self.state = state
        self.summary = Self.makeSummary(for: state, live: nil, today: today)
        self.celebration = ScreenshotMode.celebration(from: summary)
        if state.useSampleData {
            self.race = RaceStatus.sample(today: today, summary: summary, now: Date())
            self.questWindowSteps = QuestProgress.sampleWindowSteps(today: today, steps: summary.todayResult.steps, now: Date())
        }
        if awardCompletedQuests() {
            self.summary = Self.makeSummary(for: self.state, live: nil, today: today)
        }
    }

    var showsSampleDataBanner: Bool {
        state.useSampleData && !ScreenshotMode.isActive
    }

    /// Today's goal.
    var goal: Int {
        RewardEngine.goal(for: Day(Date()), changes: state.goalChanges)
    }

    /// The tier whose app icon is in use.
    var iconTier: Int {
        state.iconTier ?? summary.level.tier.number
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
        guard state.hasOnboarded, !isRefreshing, !ScreenshotMode.isActive else { return }
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
        await refreshRace()
        await refreshQuestWindows()
    }

    /// Looks up how many steps earlier days had by this time of day.
    func refreshRace() async {
        let now = Date()
        let today = Day(now)
        raceRefreshedAt = now
        if state.useSampleData {
            race = RaceStatus.sample(today: today, summary: summary, now: now)
            return
        }
        let elapsed = now.timeIntervalSince(today.startDate())
        var rivals: [RaceStatus.Rival] = []
        for rival in RaceStatus.rivalDays(today: today, summary: summary) {
            let start = rival.day.startDate()
            let end = start.addingTimeInterval(elapsed)
            let fromHealth = (try? await health.steps(from: start, to: end)) ?? nil
            let fromMotion = await motion.steps(from: start, to: end)
            let byNow = max(fromHealth ?? 0, fromMotion ?? 0)
            guard byNow > 0 || rival.total > 0 else { continue }
            rivals.append(RaceStatus.Rival(name: rival.name, day: rival.day, stepsByNow: min(byNow, rival.total),
                                           dayTotal: rival.total))
        }
        race = rivals.isEmpty ? nil : RaceStatus(rivals: rivals, asOf: now)
    }

    /// The race moves with the clock, so it is looked up again every couple of minutes while walking.
    private func refreshRaceIfStale() {
        guard let refreshed = raceRefreshedAt, Date().timeIntervalSince(refreshed) > 120 else { return }
        raceRefreshedAt = Date()
        Task {
            await refreshRace()
            await refreshQuestWindows()
        }
    }

    /// Looks up steps inside the time windows of today's quests, like "before 9 AM".
    func refreshQuestWindows() async {
        let now = Date()
        let today = Day(now)
        guard !state.useSampleData else {
            questWindowSteps = QuestProgress.sampleWindowSteps(today: today, steps: summary.todayResult.steps, now: now)
            recompute()
            return
        }
        let dayStart = today.startDate()
        var counts: [String: Int] = [:]
        for quest in Quests.forDay(today) {
            guard let window = quest.window else { continue }
            let start = dayStart.addingTimeInterval(Double(window.lowerBound) * 60)
            let end = min(now, dayStart.addingTimeInterval(Double(window.upperBound) * 60))
            guard end > start else { continue }
            let fromHealth = (try? await health.steps(from: start, to: end)) ?? nil
            let fromMotion = await motion.steps(from: start, to: end)
            counts[quest.id] = max(fromHealth ?? 0, fromMotion ?? 0)
        }
        questWindowSteps = counts
        recompute()
    }

    /// Updates today's quest progress and records XP for any quest just completed.
    /// Returns true if new XP was recorded.
    private func awardCompletedQuests() -> Bool {
        let now = Date()
        let today = Day(now)
        let todayResult = summary.todayResult
        let context = QuestContext(
            minutesIntoDay: Int(now.timeIntervalSince(today.startDate()) / 60),
            steps: todayResult.steps,
            goal: todayResult.goal,
            yesterdaySteps: summary.result(for: today.adding(days: -1))?.steps ?? 0,
            windowSteps: questWindowSteps,
            longestWalkMinutes: 0)
        quests = Quests.forDay(today).map { QuestProgress(quest: $0, state: Quests.state(of: $0, in: context)) }

        guard state.hasOnboarded, !state.useSampleData, !ScreenshotMode.isActive else { return false }
        let recorded = Set(state.bonuses.filter { $0.day == today }.map(\.id))
        let fresh = quests.filter { $0.state == .done }
            .map { Quests.bonus(for: $0.quest, on: today) }
            .filter { !recorded.contains($0.id) }
        guard !fresh.isEmpty else { return false }
        state.bonuses.append(contentsOf: fresh)
        save()
        return true
    }

    func startLiveUpdates() {
        let today = Day(Date())
        guard state.hasOnboarded, !ScreenshotMode.isActive, liveDay != today else { return }
        stopLiveUpdates()
        liveDay = today
        pedometerSteps = savedSteps(on: today)
        detectedSincePedometer = 0
        liveEstimate = nil
        motion.startLiveUpdates(for: today) { [weak self] activity in
            Task { @MainActor in self?.applyPedometer(activity) }
        }
        detector.start { [weak self] in
            Task { @MainActor in self?.applyDetectedStep() }
        }
    }

    func stopLiveUpdates() {
        motion.stopLiveUpdates()
        detector.stop()
        liveDay = nil
    }

    private func applyPedometer(_ activity: DayActivity) {
        guard activity.day == Day(Date()) else {
            // Midnight passed while the app was open; start counting the new day.
            Task { await refresh() }
            return
        }
        let before = displayedSteps(on: activity.day)
        pedometerSteps = activity.steps
        detectedSincePedometer = 0
        if activity.steps > 0, activity.meters > 0 {
            metersPerStep = activity.meters / Double(activity.steps)
        }
        merge([activity])
        if displayedSteps(on: activity.day) > before { lastLiveStep = Date() }
        recompute()
        refreshRaceIfStale()
    }

    private func applyDetectedStep() {
        let today = Day(Date())
        guard liveDay == today else { return }
        detectedSincePedometer += 1
        let estimate = pedometerSteps + detectedSincePedometer
        guard estimate > displayedSteps(on: today) else { return }
        liveEstimate = DayActivity(day: today, steps: estimate, meters: Double(estimate) * metersPerStep)
        lastLiveStep = Date()
        recompute()
        refreshRaceIfStale()
    }

    private func savedSteps(on day: Day) -> Int {
        state.activity.first { $0.day == day }?.steps ?? 0
    }

    private func displayedSteps(on day: Day) -> Int {
        max(savedSteps(on: day), liveEstimate?.day == day ? liveEstimate?.steps ?? 0 : 0)
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

    // MARK: - Settings

    func setGoal(_ goal: Int) {
        let today = Day(Date())
        state.goalChanges.removeAll { $0.from == today }
        state.goalChanges.append(GoalChange(from: today, goal: goal))
        save()
        recompute()
    }

    func setUseSampleData(_ on: Bool) {
        state.useSampleData = on
        save()
        recompute()
        Task { await refreshRace() }
    }

    /// Picks the app icon for `tier`, or nil to match the current tier from now on.
    func setIconTier(_ tier: Int?) {
        state.iconTier = tier
        save()
        AppIcon.apply(tier: iconTier)
    }

    func finishCelebration() {
        let reachedNewTier = celebration.contains { unlock in
            if case .levelUp(let level, _) = unlock.kind {
                return Levels.tier(forLevel: level).firstLevel == level
            }
            return false
        }
        state.celebrated.formUnion(celebration.map(\.id))
        celebration = []
        save()
        if reachedNewTier && state.iconTier == nil {
            AppIcon.apply(tier: iconTier)
        }
    }

    func save() {
        guard !ScreenshotMode.isActive else { return }
        StateStore.save(state)
    }

    // MARK: - Rewards

    private func recompute() {
        let today = Day(Date())
        let live = liveEstimate?.day == today ? liveEstimate : nil
        summary = Self.makeSummary(for: state, live: live, today: today)
        if awardCompletedQuests() {
            summary = Self.makeSummary(for: state, live: live, today: today)
        }
        guard state.hasOnboarded, !state.useSampleData else { return }
        let showing = Set(celebration.map(\.id))
        let fresh = summary.unlocks.filter { !state.celebrated.contains($0.id) && !showing.contains($0.id) }
        celebration.append(contentsOf: fresh)
    }

    private static func makeSummary(for state: SavedState, live: DayActivity?, today: Day) -> RewardSummary {
        if state.useSampleData {
            let sample = SampleData.activity(endingOn: today)
            return RewardEngine.summarize(RewardInput(
                activity: sample.activity, startDay: sample.startDay, today: today,
                goalChanges: state.goalChanges))
        }
        // The engine keeps the higher count when a day appears twice.
        return RewardEngine.summarize(RewardInput(
            activity: state.activity + (live.map { [$0] } ?? []), startDay: state.startDay, today: today,
            goalChanges: state.goalChanges, bonuses: state.bonuses))
    }
}
