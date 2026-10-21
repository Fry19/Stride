import StrideCore
import SwiftUI

/// Badges, passport stamps and streak freezes.
struct TrophiesView: View {
    @Environment(AppModel.self) private var model
    @State private var openBadge: BadgeProgress?
    @State private var showingRecap = ScreenshotMode.screen == "recap"

    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let stampColumns = [GridItem(.adaptive(minimum: 96), spacing: 14)]

    var body: some View {
        let summary = model.summary
        let stamps = summary.stamps
        let earned = summary.badges.filter(\.isUnlocked).count
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(eyebrow: "\(earned) of \(summary.badges.count) badges", title: "Trophies")
                if model.showsSampleDataBanner {
                    SampleDataBanner()
                }

                Button {
                    showingRecap = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.ember)
                            .frame(width: 44, height: 44)
                            .background(Theme.ember.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your recap")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Your week or month on one card, ready to share.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .glass(radius: 22, padding: 14)
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    StatTile(label: "Stamps", value: stamps.count.formatted()) {
                        Image(systemName: "seal.fill").foregroundStyle(Theme.stampInks[0])
                    }
                    StatTile(label: "Best streak", value: summary.bestStreak.formatted()) {
                        Image(systemName: "flame.fill").foregroundStyle(Theme.ember)
                    }
                    StatTile(label: "Freezes", value: summary.freezes.formatted()) {
                        Image(systemName: "snowflake").foregroundStyle(Theme.frost)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "Badges")
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

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "Passport")
                    if stamps.isEmpty {
                        HStack(spacing: 16) {
                            StampPlaceholder(size: 76)
                            Text("Hit today's goal to get your first stamp.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .glass()
                    } else {
                        LazyVGrid(columns: stampColumns, spacing: 18) {
                            ForEach(stamps) { result in
                                StampView(day: result.day, steps: result.steps)
                            }
                        }
                        .glass()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Streak freezes")
                    Text("Every \(RewardRules.streakDaysPerFreeze) days in a row earns a freeze, up to \(RewardRules.maxFreezes) saved. If you miss your goal, a freeze is used automatically and your streak carries on.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .glass()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground(glow: Theme.ember))
        .sheet(isPresented: $showingRecap) {
            RecapView()
        }
        .sheet(item: $openBadge) { progress in
            BadgeDetail(progress: progress)
                .presentationDetents([.medium])
                .presentationBackground(Theme.background)
        }
    }
}

private struct BadgeDetail: View {
    let progress: BadgeProgress

    var body: some View {
        VStack(spacing: 16) {
            BadgeEmblem(badge: progress.badge, isUnlocked: progress.isUnlocked, size: 96)
            Text(progress.badge.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Text(progress.badge.detail)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let day = progress.unlockedOn {
                Text("Earned \(StrideFormat.date(day))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.live)
            } else {
                VStack(spacing: 8) {
                    XPBar(fraction: progress.fraction)
                    Text(progress.progressText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 40)
            }
            Text("+\(StrideFormat.xp(progress.badge.xp))")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.xpColors[0])
        }
        .padding(24)
    }
}
