import Charts
import StrideCore
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false
    @State private var showingRecap = false
    @State private var showingWalk = false
    let openLevel: () -> Void

    var body: some View {
        let summary = model.summary
        let today = summary.todayResult
        let level = summary.level
        ScrollView {
            VStack(spacing: 20) {
                ScreenHeader(eyebrow: StrideFormat.longDate(today.day), title: "Today") {
                    HStack(spacing: 10) {
                        Button(action: openLevel) {
                            LevelChip(level: level)
                        }
                        GlassIconButton(systemImage: "gearshape.fill", label: "Settings") {
                            showingSettings = true
                        }
                    }
                }
                if model.showsSampleDataBanner {
                    SampleDataBanner()
                }
                hero(today)
                WalkLauncher {
                    showingWalk = true
                }
                if let race = model.race, !race.rivals.isEmpty {
                    RaceCard(race: race, steps: today.steps)
                }
                if !model.quests.isEmpty {
                    QuestCard(quests: model.quests)
                }
                Button(action: openLevel) {
                    LevelCard(level: level)
                }
                .buttonStyle(.plain)
                HStack(spacing: 12) {
                    StatTile(label: "Distance", value: StrideFormat.distance(meters: today.meters)) {
                        Image(systemName: "ruler.fill")
                            .foregroundStyle(Theme.frost)
                    }
                    StatTile(label: "XP today", value: today.xp.formatted()) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.xpColors[0])
                    }
                    StatTile(label: streakLabel(summary), value: summary.currentStreak.formatted()) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Theme.ember)
                    }
                }
                WeekChart(days: summary.lastDays(7)) {
                    showingRecap = true
                }
                UpNextCard(summary: summary)
                if !model.walks.isEmpty {
                    RecentWalks(walks: model.walks)
                }
                if showsHealthHint(summary) {
                    HealthHint()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground(glow: level.tier.color))
        .refreshable {
            await model.refresh()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingRecap) {
            RecapView()
        }
        .fullScreenCover(isPresented: $showingWalk) {
            WalkView()
        }
        .sensoryFeedback(.success, trigger: today.goalMet)
    }

    private func hero(_ today: DayResult) -> some View {
        VStack(spacing: 18) {
            ZStack {
                StepRing(steps: today.steps, goal: today.goal)
                    .frame(width: 280, height: 280)
                VStack(spacing: 4) {
                    LiveLabel(lastStep: model.lastLiveStep)
                    Text(today.steps.formatted())
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(today.steps)))
                        .animation(.snappy(duration: 0.25), value: today.steps)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(today.goalMet ? "Goal reached" : "of \(today.goal.formatted())")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(today.goalMet ? Theme.goldColors[1] : Theme.textSecondary)
                }
                .padding(.horizontal, 44)
            }
            Text(statusLine(today))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func statusLine(_ today: DayResult) -> String {
        if today.goalMet {
            return "Stamp earned and +\(StrideFormat.xp(RewardRules.goalBonusXP)) goal bonus."
        }
        return "\((today.goal - today.steps).formatted()) steps to go for +\(StrideFormat.xp(RewardRules.goalBonusXP))"
    }

    private func streakLabel(_ summary: RewardSummary) -> String {
        switch summary.freezes {
        case 0: return "Day streak"
        case 1: return "Streak · 1 freeze"
        default: return "Streak · \(summary.freezes) freezes"
        }
    }

    private func showsHealthHint(_ summary: RewardSummary) -> Bool {
        !model.state.useSampleData && summary.lastDays(7).allSatisfy { $0.steps == 0 }
    }
}

/// "LIVE" with a pulsing dot while steps are coming in, otherwise "STEPS".
private struct LiveLabel: View {
    let lastStep: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { context in
            let isLive = lastStep.map { context.date.timeIntervalSince($0) < 10 } ?? false
            HStack(spacing: 6) {
                if isLive {
                    LiveDot()
                }
                Text(isLive ? "LIVE" : "STEPS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(isLive ? Theme.live : Theme.textTertiary)
            }
            .animation(.easeInOut(duration: 0.3), value: isLive)
        }
    }
}

private struct QuestCard: View {
    let quests: [QuestProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Today's quests")
                Spacer()
                Text("\(quests.filter { $0.state == .done }.count) of \(quests.count) done")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            ForEach(quests) { progress in
                QuestRow(progress: progress)
            }
        }
        .glass()
    }
}

private struct QuestRow: View {
    let progress: QuestProgress

    private var isDone: Bool { progress.state == .done }
    private var isMissed: Bool {
        if case .missed = progress.state { return true }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isDone ? "checkmark" : progress.quest.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isDone ? Theme.background : Theme.xpColors[0])
                .frame(width: 38, height: 38)
                .background {
                    if isDone {
                        Circle().fill(LinearGradient(colors: Theme.xpColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else {
                        Circle().fill(Theme.xpColors[0].opacity(0.12))
                    }
                }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(progress.quest.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("+\(StrideFormat.xp(progress.quest.xp))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isDone ? Theme.xpColors[0] : Theme.textTertiary)
                }
                Text(progress.quest.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                if !isDone {
                    HStack(spacing: 10) {
                        XPBar(fraction: progress.fraction, height: 5)
                        Text(isMissed ? "Missed" : progressText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                            .fixedSize()
                    }
                }
            }
        }
        .opacity(isMissed ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        guard case .inProgress(let current, let target) = progress.state else { return "" }
        if case .walk = progress.quest.kind {
            return "\(current) / \(target) min"
        }
        return "\(current.formatted()) / \(target.formatted())"
    }
}

/// Today against earlier days at the same time of day.
private struct RaceCard: View {
    let race: RaceStatus
    let steps: Int

    private var lead: Int { steps - (race.rivals.first?.stepsByNow ?? 0) }
    private var scale: Double {
        Double(max(1, race.rivals.map(\.stepsByNow).max() ?? 0, steps)) * 1.08
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Race your past self")
                Spacer()
                Text("at \(race.asOf.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            if let first = race.rivals.first {
                Text(headline(against: first))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(lead >= 0 ? Theme.live : Theme.ember)
                    .contentTransition(.numericText(value: Double(lead)))
                    .animation(.snappy(duration: 0.25), value: lead)
            }
            VStack(spacing: 12) {
                RaceLane(name: "You", value: steps, fraction: Double(steps) / scale, isYou: true)
                ForEach(race.rivals) { rival in
                    RaceLane(name: rival.name, value: rival.stepsByNow, fraction: Double(rival.stepsByNow) / scale,
                             isYou: false)
                }
            }
            if let first = race.rivals.first {
                Text("\(first.name) you finished with \(first.dayTotal.formatted()) steps.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .glass()
    }

    private func headline(against rival: RaceStatus.Rival) -> String {
        let name = rival.name.lowercased()
        if lead == 0 { return "Neck and neck with \(name)" }
        return lead > 0
            ? "\(lead.formatted()) steps ahead of \(name)"
            : "\((-lead).formatted()) steps behind \(name)"
    }
}

private struct RaceLane: View {
    let name: String
    let value: Int
    let fraction: Double
    let isYou: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isYou ? Color.white : Theme.textSecondary)
                Spacer()
                Text(value.formatted())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isYou ? Color.white : Theme.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(isYou
                              ? AnyShapeStyle(LinearGradient(colors: Theme.ringColors, startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.white.opacity(0.28)))
                        .frame(width: max(8, geometry.size.width * min(fraction, 1)))
                        .shadow(color: isYou ? Theme.ember.opacity(0.5) : .clear, radius: 6)
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: fraction)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WeekChart: View {
    let days: [DayResult]
    let openRecap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Last 7 days")
                Spacer()
                Button(action: openRecap) {
                    HStack(spacing: 4) {
                        Text("\(days.reduce(0) { $0 + $1.steps }.formatted()) steps")
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Open your recap")
            }
            Chart {
                ForEach(days) { result in
                    BarMark(
                        x: .value("Day", result.day.startDate(), unit: .day),
                        y: .value("Steps", result.steps),
                        width: .ratio(0.55))
                        .foregroundStyle(result.goalMet
                            ? AnyShapeStyle(LinearGradient(colors: Theme.ringColors.reversed(), startPoint: .bottom, endPoint: .top))
                            : AnyShapeStyle(Color.white.opacity(0.16)))
                        .cornerRadius(6)
                }
                if let goal = days.last?.goal {
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
        }
        .glass()
    }
}

private struct UpNextCard: View {
    let summary: RewardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Up next")
            if let next = summary.level.nextTier {
                UpNextRow(title: "\(next.tier.name) tier", detail: "\(StrideFormat.xp(next.xpNeeded)) to go") {
                    EmblemImage(tier: next.tier)
                        .frame(width: 30, height: 30)
                }
            }
            if let stop = summary.journey.nextStop, let km = summary.journey.kmToNextStop {
                UpNextRow(title: stop.name,
                          detail: "≈ \(StrideFormat.distance(km: km)) to go on the \(summary.journey.route.name)") {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color.route(summary.journey.route.id))
                }
            }
            if let badge = nextBadge {
                UpNextRow(title: badge.badge.name, detail: badge.progressText) {
                    Image(systemName: badge.badge.symbol)
                        .foregroundStyle(Theme.ember)
                }
            }
        }
        .glass()
    }

    private var nextBadge: BadgeProgress? {
        summary.badges.filter { !$0.isUnlocked }.max { $0.fraction < $1.fraction }
    }
}

private struct UpNextRow<Icon: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 14) {
            icon
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HealthHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No steps showing?", systemImage: "heart.text.square")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Open the Health app, tap your profile picture, then Apps → Stride, and turn on Steps and Walking + Running Distance. Then pull down here to refresh.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .glass()
    }
}
