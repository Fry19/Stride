import Charts
import StrideCore
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false

    var body: some View {
        let summary = model.summary
        let today = summary.todayResult
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if model.showsSampleDataBanner {
                        SampleDataBanner()
                    }
                    hero(today)
                    HStack(spacing: 12) {
                        StatTile(label: "Distance", value: StrideFormat.distance(meters: today.meters)) {
                            Image(systemName: "figure.walk").foregroundStyle(Color.pine)
                        }
                        StatTile(label: "Coins today", value: today.coins.formatted()) {
                            CoinIcon(size: 20)
                        }
                        StatTile(label: streakLabel(summary), value: summary.currentStreak.formatted()) {
                            Image(systemName: "flame.fill").foregroundStyle(Color.blaze)
                        }
                    }
                    WeekChart(days: summary.lastDays(7))
                    UpNextCard(summary: summary, rewards: model.state.rewards)
                    if showsHealthHint(summary) {
                        HealthHint()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable {
                await model.refresh()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func hero(_ today: DayResult) -> some View {
        VStack(spacing: 18) {
            Text(StrideFormat.longDate(today.day).uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            ZStack {
                StepRing(steps: today.steps, goal: today.goal)
                VStack(spacing: 0) {
                    Text(today.steps.formatted())
                        .font(.system(size: 60, weight: .black))
                        .fontWidth(.compressed)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(today.steps)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("of \(today.goal.formatted()) steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(44)
            }
            .frame(width: 250, height: 250)
            Text(statusLine(today))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .card()
        .overlay(alignment: .topTrailing) {
            if today.goalMet {
                StampView(day: today.day, steps: today.steps, size: 78)
                    .padding(12)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: today.goalMet)
    }

    private func statusLine(_ today: DayResult) -> String {
        if today.goalMet {
            return "Goal met. Today's stamp is in your passport."
        }
        return "\((today.goal - today.steps).formatted()) steps to today's stamp"
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

private struct WeekChart: View {
    let days: [DayResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 days")
                    .font(.headline)
                Spacer()
                Text("\(days.reduce(0) { $0 + $1.steps }.formatted()) steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Chart {
                ForEach(days) { result in
                    BarMark(
                        x: .value("Day", result.day.startDate(), unit: .day),
                        y: .value("Steps", result.steps))
                        .foregroundStyle(result.goalMet ? Color.blaze : Color.blaze.opacity(0.3))
                        .cornerRadius(5)
                }
                if let goal = days.last?.goal {
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
            }
            .frame(height: 170)
        }
        .card()
    }
}

private struct UpNextCard: View {
    let summary: RewardSummary
    let rewards: [Reward]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Up next")
                .font(.headline)
            if let stop = summary.journey.nextStop, let km = summary.journey.kmToNextStop {
                UpNextRow(title: stop.name,
                          detail: "≈ \(StrideFormat.distance(km: km)) to go on the \(summary.journey.route.name)") {
                    Image(systemName: "map.fill").foregroundStyle(Color.pine)
                }
            }
            if let badge = nextBadge {
                UpNextRow(title: badge.badge.name, detail: badge.progressText) {
                    Image(systemName: badge.badge.symbol).foregroundStyle(Color.blaze)
                }
            }
            UpNextRow(title: rewardLine.title, detail: rewardLine.detail) {
                CoinIcon(size: 20)
            }
        }
        .card()
    }

    private var nextBadge: BadgeProgress? {
        summary.badges.filter { !$0.isUnlocked }.max { $0.fraction < $1.fraction }
    }

    private var rewardLine: (title: String, detail: String) {
        let byCost = rewards.sorted { $0.cost < $1.cost }
        if let affordable = byCost.last(where: { $0.cost <= summary.balance }) {
            return (affordable.name, "You have enough coins. Redeem it in Rewards.")
        }
        if let next = byCost.first {
            return (next.name, "\(StrideFormat.coins(next.cost - summary.balance)) to go")
        }
        return ("Pick a reward", "Add a treat in Rewards to save your coins for.")
    }
}

private struct UpNextRow<Icon: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 14) {
            icon
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
            Text("Open the Health app, tap your profile picture, then Apps → Stride, and turn on Steps and Walking + Running Distance. Then pull down here to refresh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}
