import StrideCore
import SwiftUI

/// Your shoe, how it evolves with your level, and the app icon.
struct LockerView: View {
    @Environment(AppModel.self) private var model

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        let level = model.summary.level
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(eyebrow: "Tier \(level.tier.number) of \(Levels.tiers.count)", title: "Locker")

                VStack(spacing: 14) {
                    ShoeHero(tier: level.tier, height: 150)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    VStack(spacing: 6) {
                        Text(level.tier.name)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        Text(level.tier.tagline)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    VStack(spacing: 8) {
                        HStack {
                            Text("Level \(level.level)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Spacer()
                            Text(level.isMaxLevel
                                 ? StrideFormat.xp(level.xp)
                                 : "\(level.xpIntoLevel.formatted()) / \(StrideFormat.xp(level.xpForLevel))")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white)
                        XPBar(fraction: level.fraction, height: 10)
                        if let next = level.nextTier {
                            Text("\(StrideFormat.xp(next.xpNeeded)) until the \(next.tier.name) shoe")
                                .font(.footnote)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 4)
                }
                .glass(radius: 28, padding: 20)

                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Evolution")
                        .padding(.bottom, 10)
                    ForEach(Levels.tiers) { tier in
                        TierRow(tier: tier, current: level.tier)
                        if tier.number < Levels.tiers.count {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .glass()

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "App icon")
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(Levels.tiers) { tier in
                            IconChoice(tier: tier,
                                       isUnlocked: tier.number <= level.tier.number,
                                       isSelected: tier.number == model.iconTier) {
                                model.setIconTier(tier.number == level.tier.number ? nil : tier.number)
                            }
                        }
                    }
                    Toggle(isOn: matchTier) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Match my tier")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("The icon upgrades whenever you unlock a new shoe.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.ember)
                }
                .glass()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground(glow: level.tier.color))
    }

    private var matchTier: Binding<Bool> {
        Binding(get: { model.state.iconTier == nil },
                set: { model.setIconTier($0 ? nil : model.iconTier) })
    }
}

private struct TierRow: View {
    let tier: Tier
    let current: Tier

    private var isUnlocked: Bool { tier.number <= current.number }

    var body: some View {
        HStack(spacing: 14) {
            ShoeImage(tier: tier, locked: !isUnlocked)
                .frame(width: 78, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(isUnlocked ? tier.name : "Tier \(tier.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? Color.white : Theme.textSecondary)
                Text(tier.levelRange)
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if tier == current {
                Text("WEARING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tier.color, in: Capsule())
            } else if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.live)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct IconChoice: View {
    let tier: Tier
    let isUnlocked: Bool
    let isSelected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Image(tier.iconPreviewName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .saturation(isUnlocked ? 1 : 0)
                .opacity(isUnlocked ? 1 : 0.3)
                .overlay {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Theme.ember : Color.clear, lineWidth: 2.5)
                        .padding(-4)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityLabel("\(tier.name) icon")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
