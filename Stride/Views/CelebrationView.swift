import StrideCore
import SwiftUI

/// Shown full screen when you level up or earn stamps, badges or postcards.
/// A new tier gets a shoe reveal.
struct CelebrationView: View {
    let unlocks: [Unlock]
    let level: LevelProgress
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var spinning = false

    private var levelsReached: [Int] {
        unlocks.compactMap { unlock in
            if case .levelUp(let level, _) = unlock.kind { return level }
            return nil
        }
    }

    /// The highest new tier reached, if any level-up started one.
    private var newTier: Tier? {
        levelsReached.filter { Levels.tier(forLevel: $0).firstLevel == $0 }.max().map { Levels.tier(forLevel: $0) }
    }

    private var others: [Unlock] {
        unlocks.filter { unlock in
            if case .levelUp = unlock.kind { return false }
            return true
        }
    }

    private var bonusXP: Int {
        others.reduce(0) { total, unlock in
            switch unlock.kind {
            case .stamp: return total + RewardRules.goalBonusXP
            case .badge(let badge, _): return total + badge.xp
            case .stop, .freezeUsed, .levelUp: return total
            }
        }
    }

    private var glow: Color { (newTier ?? level.tier).color }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            rays
            ScrollView {
                VStack(spacing: 22) {
                    hero
                        .padding(.top, 36)
                    if bonusXP > 0 {
                        Text("+\(StrideFormat.xp(bonusXP))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.xpColors[0])
                    }
                    ForEach(Array(others.enumerated()), id: \.element.id) { index, unlock in
                        UnlockRow(unlock: unlock)
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 24)
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(0.35 + Double(index) * 0.08), value: appeared)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Collect", action: onDone)
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .onAppear {
            appeared = true
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private var rays: some View {
        let colors = (0..<10).flatMap { _ in [glow.opacity(0.22), Color.clear] }
        return Circle()
            .fill(AngularGradient(gradient: Gradient(colors: colors), center: .center))
            .frame(width: 640, height: 640)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 30, endRadius: 320))
            .overlay(RadialGradient(colors: [glow.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 220))
            .offset(y: -170)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var hero: some View {
        if let tier = newTier {
            VStack(spacing: 14) {
                SectionLabel(text: "New shoe unlocked")
                ShoeHero(tier: tier, height: 160)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                    .opacity(appeared || reduceMotion ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.62), value: appeared)
                Text(tier.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                Text(tier.tagline)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                LevelPill(level: levelsReached.max() ?? level.level, color: tier.color)
            }
        } else if let reached = levelsReached.max() {
            VStack(spacing: 10) {
                SectionLabel(text: "Level up")
                ShoeHero(tier: level.tier, height: 120)
                Text("Level \(reached)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: appeared)
                if let next = level.nextTier {
                    Text("\(StrideFormat.xp(next.xpNeeded)) until the \(next.tier.name) shoe")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        } else {
            Text(headline)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    private var headline: String {
        let kinds = Set(others.map(\.kindName))
        guard let first = others.first, kinds.count == 1 else { return "Nice walking!" }
        switch first.kind {
        case .stamp: return others.count > 1 ? "New stamps!" : "Stamp earned!"
        case .badge: return others.count > 1 ? "New badges!" : "Badge earned!"
        case .stop: return others.count > 1 ? "New postcards!" : "New postcard!"
        case .freezeUsed: return "Streak saved"
        case .levelUp: return "Level up!"
        }
    }
}

private struct LevelPill: View {
    let level: Int
    let color: Color

    var body: some View {
        Text("LEVEL \(level)")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(color, in: Capsule())
    }
}

private extension Unlock {
    var kindName: String {
        switch kind {
        case .stamp: return "stamp"
        case .badge: return "badge"
        case .stop: return "stop"
        case .freezeUsed: return "freeze"
        case .levelUp: return "level"
        }
    }
}

private struct UnlockRow: View {
    let unlock: Unlock

    var body: some View {
        HStack(spacing: 16) {
            icon
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let xp {
                    Text("+\(StrideFormat.xp(xp))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.xpColors[0])
                }
            }
            Spacer(minLength: 0)
        }
        .glass(radius: 22, padding: 14)
    }

    @ViewBuilder private var icon: some View {
        switch unlock.kind {
        case .stamp(let result):
            StampView(day: result.day, steps: result.steps, size: 62)
        case .badge(let badge, _):
            BadgeEmblem(badge: badge, isUnlocked: true, size: 56)
        case .stop(let reached):
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.route(reached.route.id))
                .frame(width: 56, height: 56)
                .background(Color.route(reached.route.id).opacity(0.16), in: Circle())
        case .freezeUsed:
            Image(systemName: "snowflake")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.frost)
                .frame(width: 56, height: 56)
                .background(Theme.frost.opacity(0.16), in: Circle())
        case .levelUp:
            EmptyView()
        }
    }

    private var title: String {
        switch unlock.kind {
        case .stamp: return "Goal met"
        case .badge(let badge, _): return badge.name
        case .stop(let reached): return reached.stop.name
        case .freezeUsed: return "Streak saved"
        case .levelUp(let level, _): return "Level \(level)"
        }
    }

    private var detail: String {
        switch unlock.kind {
        case .stamp(let result): return "\(StrideFormat.longDate(result.day)) · \(result.steps.formatted()) steps"
        case .badge(let badge, _): return badge.detail
        case .stop(let reached): return "New postcard from the \(reached.route.name)"
        case .freezeUsed(let day): return "A freeze covered \(StrideFormat.date(day)), so your streak lives on."
        case .levelUp: return ""
        }
    }

    private var xp: Int? {
        switch unlock.kind {
        case .stamp: return RewardRules.goalBonusXP
        case .badge(let badge, _): return badge.xp
        case .stop, .freezeUsed, .levelUp: return nil
        }
    }
}
