import StrideCore
import SwiftUI

struct PassportView: View {
    @Environment(AppModel.self) private var model
    @State private var openBadge: BadgeProgress?

    private let stampColumns = [GridItem(.adaptive(minimum: 96), spacing: 14)]
    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        let summary = model.summary
        let stamps = summary.stamps
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if model.showsSampleDataBanner {
                        SampleDataBanner()
                    }

                    HStack(spacing: 12) {
                        StatTile(label: "Stamps", value: stamps.count.formatted()) {
                            Image(systemName: "seal.fill").foregroundStyle(Color.stampInks[0])
                        }
                        StatTile(label: "Best streak", value: summary.bestStreak.formatted()) {
                            Image(systemName: "flame.fill").foregroundStyle(Color.blaze)
                        }
                        StatTile(label: "Freezes saved", value: summary.freezes.formatted()) {
                            Image(systemName: "snowflake").foregroundStyle(Color.frost)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Stamps", detail: "One for each day you hit your goal")
                        if stamps.isEmpty {
                            HStack(spacing: 16) {
                                StampPlaceholder(size: 80)
                                Text("Hit today's goal to get your first stamp.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .card()
                        } else {
                            LazyVGrid(columns: stampColumns, spacing: 18) {
                                ForEach(stamps) { result in
                                    StampView(day: result.day, steps: result.steps)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(
                            title: "Badges",
                            detail: "\(summary.badges.filter(\.isUnlocked).count) of \(summary.badges.count) earned · tap for details")
                        LazyVGrid(columns: badgeColumns, spacing: 12) {
                            ForEach(summary.badges) { progress in
                                Button {
                                    openBadge = progress
                                } label: {
                                    BadgeTile(progress: progress)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Streak freezes", detail: nil)
                        Text("Every \(RewardRules.streakDaysPerFreeze) days in a row earns a freeze, up to \(RewardRules.maxFreezes) saved. If you miss your goal, a freeze is used automatically and your streak carries on.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .card()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Passport")
            .sheet(item: $openBadge) { progress in
                BadgeDetail(progress: progress)
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BadgeDetail: View {
    let progress: BadgeProgress

    var body: some View {
        VStack(spacing: 16) {
            BadgeEmblem(badge: progress.badge, isUnlocked: progress.isUnlocked, size: 96)
            Text(progress.badge.name)
                .font(.system(size: 32, weight: .black))
                .fontWidth(.condensed)
            Text(progress.badge.detail)
                .font(.body)
                .multilineTextAlignment(.center)
            if let day = progress.unlockedOn {
                Text("Earned \(StrideFormat.date(day))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pine)
            } else {
                VStack(spacing: 6) {
                    ProgressView(value: progress.fraction)
                        .tint(Color.blaze)
                    Text(progress.progressText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            }
            CoinAmount(value: progress.badge.bonus, prefix: "+", iconSize: 18)
                .font(.headline)
        }
        .padding(24)
    }
}
