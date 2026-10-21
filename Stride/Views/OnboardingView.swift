import StrideCore
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var goal = RewardRules.defaultGoal
    @State private var isConnecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                EmblemHero(tier: Levels.tiers[0], size: 120)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)

                VStack(alignment: .leading, spacing: 10) {
                    Text("STRIDE")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(6)
                        .foregroundStyle(Theme.ember)
                    Text("Every step levels you up.")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("You start at Chalk. Walk to earn XP, climb 50 levels and work your way up through ten materials, from copper and gold to aurora.")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    FeatureRow(symbol: "sparkles", color: Theme.xpColors[0], title: "Earn XP",
                               text: "Every step is 1 XP, and hitting your daily goal adds 1,500 more.")
                    FeatureRow(symbol: "arrow.up.circle.fill", color: Theme.ember, title: "Climb the tiers",
                               text: "A new material every 5 levels. Your app icon changes to match.")
                    FeatureRow(symbol: "map.fill", color: Color.route("camino"), title: "Collect along the way",
                               text: "Stamps for goal days, badges for milestones, and postcards from three famous trails.")
                }
                .glass()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Daily goal")
                    Stepper(value: $goal, in: 1_000...30_000, step: 500) {
                        Text("\(goal.formatted()) steps")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    Text("8,000 is a good start. You can change it any time.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .glass()

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        isConnecting = true
                        Task {
                            await model.completeOnboarding(goal: goal)
                            isConnecting = false
                        }
                    } label: {
                        Text(isConnecting ? "Connecting…" : "Connect Apple Health")
                    }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(isConnecting)

                    Text("Stride only reads your steps and walking distance, and everything stays on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground(glow: Levels.tiers[0].color))
    }
}

private struct FeatureRow: View {
    let symbol: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
