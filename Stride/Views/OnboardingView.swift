import StrideCore
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var goal = RewardRules.defaultGoal
    @State private var isConnecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STRIDE")
                        .font(.system(size: 72, weight: .black))
                        .fontWidth(.compressed)
                        .foregroundStyle(Color.blaze)
                    Text("Walk more. Earn stamps, coins and a journey across three famous trails.")
                        .font(.title3.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(title: "A stamp for every goal day",
                               text: "Hit your daily step goal and your passport gets a stamp. String days together for a streak.") {
                        Image(systemName: "seal.fill").foregroundStyle(Color.stampInks[0])
                    }
                    FeatureRow(title: "Coins for real treats",
                               text: "Earn a coin for every 100 steps, then spend them on rewards you pick, like a fancy coffee.") {
                        CoinIcon(size: 26)
                    }
                    FeatureRow(title: "A journey to walk",
                               text: "Your distance carries you along the Inca Trail, Hadrian's Wall and the Camino de Santiago, with a postcard at every stop.") {
                        Image(systemName: "map.fill").foregroundStyle(Color.pine)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily goal")
                        .font(.headline)
                    Stepper(value: $goal, in: 1_000...30_000, step: 500) {
                        Text("\(goal.formatted()) steps")
                            .monospacedDigit()
                    }
                    Text("8,000 is a good start. You can change it later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        isConnecting = true
                        Task {
                            await model.completeOnboarding(goal: goal)
                            isConnecting = false
                        }
                    } label: {
                        Text(isConnecting ? "Connecting…" : "Connect Apple Health")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isConnecting)

                    Text("Stride only reads your steps and walking distance, and everything stays on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct FeatureRow<Icon: View>: View {
    let title: String
    let text: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            icon
                .font(.title)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
