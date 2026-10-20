import StrideCore
import SwiftUI

/// Shown when new stamps, badges or postcards are earned.
struct CelebrationView: View {
    let unlocks: [Unlock]
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    Text(headline)
                        .font(.system(size: 44, weight: .black))
                        .fontWidth(.compressed)
                        .multilineTextAlignment(.center)
                        .padding(.top, 28)
                    if bonusCoins > 0 {
                        CoinAmount(value: bonusCoins, prefix: "+", iconSize: 22)
                            .font(.title3.weight(.bold))
                    }
                    ForEach(Array(unlocks.enumerated()), id: \.element.id) { index, unlock in
                        UnlockCard(unlock: unlock)
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.7)
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.65).delay(Double(index) * 0.12),
                                value: appeared)
                    }
                }
                .padding()
            }
            Button {
                onDone()
            } label: {
                Text("Collect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private var headline: String {
        guard let first = unlocks.first, Set(unlocks.map(\.kindName)).count == 1 else {
            return "Nice walking!"
        }
        switch first.kind {
        case .stamp: return unlocks.count > 1 ? "New stamps!" : "Stamp earned!"
        case .badge: return unlocks.count > 1 ? "New badges!" : "Badge earned!"
        case .stop: return unlocks.count > 1 ? "New postcards!" : "New postcard!"
        case .freezeUsed: return "Streak saved"
        }
    }

    /// Bonus coins from goal stamps and badges. Step coins show on the Today screen.
    private var bonusCoins: Int {
        unlocks.reduce(0) { total, unlock in
            switch unlock.kind {
            case .stamp: return total + RewardRules.goalBonus
            case .badge(let badge, _): return total + badge.bonus
            case .stop, .freezeUsed: return total
            }
        }
    }
}

private extension Unlock {
    var kindName: String {
        switch kind {
        case .stamp: return "stamp"
        case .badge: return "badge"
        case .stop: return "stop"
        case .freezeUsed: return "freeze"
        }
    }
}

private struct UnlockCard: View {
    let unlock: Unlock

    var body: some View {
        switch unlock.kind {
        case .stamp(let result):
            HStack(spacing: 16) {
                StampView(day: result.day, steps: result.steps, size: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal met")
                        .font(.headline)
                    Text("\(StrideFormat.longDate(result.day)) · \(result.steps.formatted()) steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    CoinAmount(value: RewardRules.goalBonus, prefix: "+", iconSize: 14)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            .card()
        case .badge(let badge, let day):
            HStack(spacing: 16) {
                BadgeEmblem(badge: badge, isUnlocked: true, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(badge.name)
                        .font(.headline)
                    Text(badge.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Earned \(StrideFormat.date(day))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    CoinAmount(value: badge.bonus, prefix: "+", iconSize: 14)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            .card()
        case .stop(let reached):
            PostcardView(reached: reached)
        case .freezeUsed(let day):
            HStack(spacing: 16) {
                Image(systemName: "snowflake")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.frost)
                    .frame(width: 72, height: 72)
                    .background(Color.frost.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("A streak freeze covered \(StrideFormat.date(day))")
                        .font(.headline)
                    Text("You missed your goal that day, so a saved freeze kept your streak going.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .card()
        }
    }
}
