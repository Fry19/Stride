import StrideCore
import SwiftUI

/// The longest and fastest walks.
struct WalkRecords {
    let longest: Walk?
    /// Fastest pace over walks of at least a kilometer.
    let fastest: Walk?

    init(_ walks: [Walk]) {
        longest = walks.max { $0.meters < $1.meters }
        fastest = walks.filter { $0.meters >= 1_000 }.min { $0.duration / $0.meters < $1.duration / $1.meters }
    }
}

/// Personal bests: best day, week and month, longest streak, and the longest and fastest walks.
struct RecordsCard: View {
    let summary: RewardSummary
    let walks: [Walk]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let records = StepRecords(summary: summary, firstWeekday: Calendar.current.firstWeekday)
        let walkRecords = WalkRecords(walks)
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Personal records")
            LazyVGrid(columns: columns, spacing: 12) {
                RecordTile(symbol: "trophy.fill", color: Theme.goldColors[1], title: "Best day",
                           value: records.bestDay.map { $0.steps.formatted() } ?? "–",
                           detail: records.bestDay.map { StrideFormat.date($0.day) } ?? "Walk to set one")
                RecordTile(symbol: "calendar", color: Theme.ember, title: "Best week",
                           value: records.bestWeek.map { $0.steps.formatted() } ?? "–",
                           detail: records.bestWeek.map { "Week of \(StrideFormat.date($0.start))" } ?? "Walk to set one")
                RecordTile(symbol: "calendar.badge.checkmark", color: Theme.xpColors[1], title: "Best month",
                           value: records.bestMonth.map { $0.steps.formatted() } ?? "–",
                           detail: records.bestMonth.map {
                               $0.start.startDate().formatted(.dateTime.month(.wide).year())
                           } ?? "Walk to set one")
                RecordTile(symbol: "flame.fill", color: Theme.ember, title: "Longest streak",
                           value: "\(records.longestStreak) \(records.longestStreak == 1 ? "day" : "days")",
                           detail: "\(records.goalDays.formatted()) goal days in all")
                if let longest = walkRecords.longest {
                    RecordTile(symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", color: Theme.live,
                               title: "Longest walk", value: StrideFormat.distance(meters: longest.meters, decimals: 2),
                               detail: longest.start.formatted(.dateTime.month(.abbreviated).day()))
                }
                if let fastest = walkRecords.fastest {
                    RecordTile(symbol: "hare.fill", color: Theme.frost, title: "Fastest pace",
                               value: WalkFormat.pace(seconds: fastest.duration, meters: fastest.meters),
                               detail: fastest.start.formatted(.dateTime.month(.abbreviated).day()))
                }
                RecordTile(symbol: "chart.bar.fill", color: Theme.xpColors[0], title: "Daily average",
                           value: records.dailyAverage.formatted(), detail: "steps on days you walked")
                RecordTile(symbol: "globe.europe.africa.fill", color: Theme.stampInks[2], title: "All time",
                           value: records.totalSteps.formatted(.number.notation(.compactName)),
                           detail: "steps · \(StrideFormat.distance(meters: records.totalMeters))")
            }
        }
    }
}

private struct RecordTile: View {
    let symbol: String
    let color: Color
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 20, padding: 14)
    }
}

/// The last year as a grid, one column per week, each day lit by how close it came to its goal.
struct GoalCalendar: View {
    let summary: RewardSummary

    @State private var selected: Day?

    private let cell: CGFloat = 13
    private let gap: CGFloat = 3

    var body: some View {
        let end = summary.today
        let start = end.adding(days: -364).startOfWeek(firstWeekday: Calendar.current.firstWeekday)
        let days = start.through(end)
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        let goalDays = days.filter { summary.result(for: $0)?.status == .met }.count
        let goalDaysText = "\(goalDays) goal \(goalDays == 1 ? "day" : "days") this year"
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Goal calendar")
                Spacer()
                Text(goalDaysText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: gap) {
                        ForEach(weeks.indices, id: \.self) { index in
                            Color.clear
                                .frame(width: cell, height: 11)
                                .overlay(alignment: .leading) {
                                    Text(monthLabel(weeks, at: index))
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Theme.textTertiary)
                                        .fixedSize()
                                }
                        }
                    }
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(weeks.indices, id: \.self) { index in
                            VStack(spacing: gap) {
                                ForEach(weeks[index], id: \.self) { day in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(color(for: summary.result(for: day)))
                                        .frame(width: cell, height: cell)
                                        .overlay {
                                            if day == selected {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .strokeBorder(.white, lineWidth: 1.5)
                                            }
                                        }
                                        .onTapGesture { selected = selected == day ? nil : day }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .defaultScrollAnchor(.trailing)
            .scrollIndicators(.hidden)

            if let selected {
                Text(detail(for: selected))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
            } else {
                HStack(spacing: 14) {
                    LegendItem(color: Theme.ember, label: "Goal met")
                    LegendItem(color: Theme.ember.opacity(0.32), label: "Partway")
                    LegendItem(color: Theme.frost.opacity(0.75), label: "Freeze")
                }
            }
        }
        .glass()
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func color(for result: DayResult?) -> Color {
        guard let result, result.steps > 0 else { return Color.white.opacity(0.06) }
        switch result.status {
        case .met: return Theme.ember
        case .frozen: return Theme.frost.opacity(0.75)
        default:
            let fraction = min(1, Double(result.steps) / Double(max(result.goal, 1)))
            return Theme.ember.opacity(0.12 + 0.6 * fraction)
        }
    }

    /// The month's name above the first week that starts in it.
    private func monthLabel(_ weeks: [[Day]], at index: Int) -> String {
        guard let first = weeks[index].first else { return "" }
        if index > 0, let previous = weeks[index - 1].first, previous.month == first.month { return "" }
        if index == 0 && first.day > 21 { return "" }
        return first.startDate().formatted(.dateTime.month(.abbreviated))
    }

    private func detail(for day: Day) -> String {
        let date = StrideFormat.longDate(day)
        guard let result = summary.result(for: day), result.steps > 0 else { return "\(date) · no steps" }
        switch result.status {
        case .met: return "\(date) · \(result.steps.formatted()) steps, goal met"
        case .frozen: return "\(date) · \(result.steps.formatted()) steps, saved by a freeze"
        default: return "\(date) · \(result.steps.formatted()) of \(result.goal.formatted()) steps"
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 11, height: 11)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
