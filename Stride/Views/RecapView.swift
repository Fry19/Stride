import StrideCore
import SwiftUI

/// A recap of the week or month, with a 9:16 card to share.
struct RecapView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var period: Recap.Period = .week
    /// The card rendered for sharing; redrawn when the period changes.
    @State private var shareImage: Image?

    var body: some View {
        let recap = Recap(period: period, summary: model.summary)
        NavigationStack {
            VStack(spacing: 18) {
                Picker("Period", selection: $period) {
                    ForEach(Recap.Period.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                RecapCard(recap: recap)
                    .frame(width: RecapCard.size.width, height: RecapCard.size.height)
                    .scaleEffect(0.82)
                    .frame(width: RecapCard.size.width * 0.82, height: RecapCard.size.height * 0.82)
                    .shadow(color: recap.level.tier.color.opacity(0.25), radius: 30)

                Spacer(minLength: 0)

                if let image = shareImage {
                    ShareLink(item: image, preview: SharePreview(recap.title, image: image)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(GlowButtonStyle())
                    .padding(.horizontal, 24)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Theme.background)
            .task(id: period) {
                shareImage = render(Recap(period: period, summary: model.summary))
            }
            .navigationTitle("Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(Theme.background)
    }

    /// The card as a 1080 x 1920 image, sized for Instagram Stories.
    @MainActor
    private func render(_ recap: Recap) -> Image? {
        let renderer = ImageRenderer(content: RecapCard(recap: recap)
            .frame(width: RecapCard.size.width, height: RecapCard.size.height)
            .environment(\.colorScheme, .dark))
        renderer.scale = 1080 / RecapCard.size.width
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

struct RecapCard: View {
    static let size = CGSize(width: 360, height: 640)

    let recap: Recap

    var body: some View {
        let tier = recap.level.tier
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("STRIDE")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(5)
                    .foregroundStyle(Theme.ember)
                Spacer()
                Text(recap.dateRange)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(recap.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 22)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(recap.totalSteps.formatted())
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: Theme.ringColors, startPoint: .leading, endPoint: .trailing))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("steps")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 18)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 18) {
                GridRow {
                    RecapStat(value: recap.averageSteps.formatted(), label: "Daily average")
                    RecapStat(value: "\(recap.goalDays) of \(recap.dayCount)", label: "Goal days")
                }
                GridRow {
                    RecapStat(value: StrideFormat.distance(meters: recap.meters), label: "Distance")
                    RecapStat(value: recap.xp.formatted(), label: "XP earned")
                }
                GridRow {
                    RecapStat(value: recap.bestDay.map { $0.steps.formatted() } ?? "–",
                              label: recap.bestDay.map { "Best day, \(StrideFormat.date($0.day))" } ?? "Best day")
                    RecapStat(value: "\(recap.bestStreak) days", label: "Longest streak")
                }
            }
            .padding(.top, 26)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                EmblemImage(tier: tier)
                    .frame(width: 56, height: 56)
                    .shadow(color: tier.color.opacity(0.4), radius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(recap.level.level)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(tier.name) tier")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tier.color)
                }
            }
        }
        .padding(28)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background {
            ZStack {
                Theme.background
                RadialGradient(colors: [tier.color.opacity(0.35), .clear],
                               center: UnitPoint(x: 0.85, y: 0.95), startRadius: 0, endRadius: 380)
                RadialGradient(colors: [Theme.ember.opacity(0.28), .clear],
                               center: UnitPoint(x: 0.1, y: 0.25), startRadius: 0, endRadius: 320)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct RecapStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
