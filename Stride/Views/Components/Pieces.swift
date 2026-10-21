import StrideCore
import SwiftUI

/// Progress toward the daily goal: a glowing gradient arc that turns gold once the goal is met,
/// with a second inner lap for steps past the goal.
struct StepRing: View {
    let steps: Int
    let goal: Int
    var lineWidth: CGFloat = 22

    private var fraction: Double { goal > 0 ? Double(steps) / Double(goal) : 0 }
    private var colors: [Color] { steps >= goal ? Theme.goldColors : Theme.ringColors }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
            arc(to: min(fraction, 1), width: lineWidth)
                .blur(radius: 16)
                .opacity(0.75)
            arc(to: min(fraction, 1), width: lineWidth)
            if fraction > 1 {
                arc(to: min(fraction - 1, 1), width: lineWidth * 0.45, colors: Theme.xpColors)
                    .padding(lineWidth * 1.25)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: steps)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(steps.formatted()) of \(goal.formatted()) steps")
    }

    private func arc(to end: Double, width: CGFloat, colors: [Color]? = nil) -> some View {
        Circle()
            .trim(from: 0, to: max(end, 0.001))
            .stroke(
                AngularGradient(colors: colors ?? self.colors, center: .center,
                                startAngle: .degrees(-6), endAngle: .degrees(max(360 * end, 12))),
                style: StrokeStyle(lineWidth: width, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

/// A gradient progress bar for XP.
struct XPBar: View {
    let fraction: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: Theme.xpColors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geometry.size.width * min(max(fraction, 0), 1)))
                    .shadow(color: Theme.xpColors[1].opacity(0.6), radius: 8)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)
    }
}

/// A pulsing green dot shown while steps are coming in live.
struct LiveDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Theme.live)
            .frame(width: 7, height: 7)
            .background {
                Circle()
                    .fill(Theme.live.opacity(0.5))
                    .scaleEffect(pulsing ? 2.8 : 1)
                    .opacity(pulsing ? 0 : 1)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
    }
}

struct StatTile<Icon: View>: View {
    let label: String
    let value: String
    @ViewBuilder var icon: Icon

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            icon
                .font(.system(size: 17, weight: .semibold))
                .frame(height: 20)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .glass(radius: 20, padding: 14)
        .accessibilityElement(children: .combine)
    }
}

/// A rounded square with the corner radius of an app icon.
struct IconShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.225, style: .continuous)
    }
}

/// A tier's emblem, the same artwork as its app icon. Locked tiers are dimmed and gray.
struct EmblemImage: View {
    let tier: Tier
    var locked = false

    var body: some View {
        Image(tier.emblemName)
            .resizable()
            .scaledToFit()
            .clipShape(IconShape())
            .overlay(IconShape().stroke(Color.white.opacity(0.14), lineWidth: 1))
            .saturation(locked ? 0 : 1)
            .opacity(locked ? 0.25 : 1)
            .accessibilityLabel(locked ? "Locked tier" : "\(tier.name) emblem")
    }
}

/// An emblem floating over its own glow, with a soft shadow beneath.
struct EmblemHero: View {
    let tier: Tier
    var size: CGFloat = 140

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [tier.color.opacity(0.5), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 1.1))
                .frame(width: size * 2.4, height: size * 2.4)
                .blur(radius: 20)
            VStack(spacing: size * 0.14) {
                EmblemImage(tier: tier)
                    .frame(width: size, height: size)
                    .shadow(color: tier.color.opacity(0.35), radius: size * 0.18)
                    .rotation3DEffect(.degrees(floating ? 6 : -6), axis: (x: 0.2, y: 1, z: 0))
                    .offset(y: floating ? -5 : 4)
                Ellipse()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: size * 0.8, height: size * 0.08)
                    .blur(radius: 8)
                    .scaleEffect(floating ? 0.88 : 1)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

/// A small capsule with the current emblem and level.
struct LevelChip: View {
    let level: LevelProgress

    var body: some View {
        HStack(spacing: 6) {
            EmblemImage(tier: level.tier)
                .frame(width: 22, height: 22)
            Text("Lv \(level.level)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level.level), \(level.tier.name)")
    }
}

/// Current level, emblem and XP toward the next level.
struct LevelCard: View {
    let level: LevelProgress

    var body: some View {
        HStack(spacing: 16) {
            EmblemImage(tier: level.tier)
                .frame(width: 64, height: 64)
                .shadow(color: level.tier.color.opacity(0.35), radius: 12)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Level \(level.level)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Text(level.tier.name.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(level.tier.color)
                        .lineLimit(1)
                }
                XPBar(fraction: level.fraction)
                Text(level.isMaxLevel ? "Max level. Legendary." : "\(StrideFormat.xp(level.xpToNextLevel)) to level \(level.level + 1)")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
        }
        .glass()
    }
}

/// The round emblem for a badge: glowing when earned, a dashed outline when not.
struct BadgeEmblem: View {
    let badge: Badge
    let isUnlocked: Bool
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            if isUnlocked {
                Circle()
                    .fill(LinearGradient(colors: Theme.ringColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: Theme.ember.opacity(0.5), radius: size * 0.2)
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.05))
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            Image(systemName: badge.symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(isUnlocked ? Color.white : Theme.textTertiary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct BadgeTile: View {
    let progress: BadgeProgress

    var body: some View {
        VStack(spacing: 10) {
            BadgeEmblem(badge: progress.badge, isUnlocked: progress.isUnlocked)
            Text(progress.badge.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(progress.isUnlocked ? Color.white : Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            if progress.isUnlocked {
                Text("+\(StrideFormat.xp(progress.badge.xp))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.xpColors[0])
            } else {
                XPBar(fraction: progress.fraction, height: 4)
                    .padding(.horizontal, 6)
                    .frame(height: 14)
            }
        }
        .glass(radius: 20, padding: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        progress.isUnlocked ? "\(progress.badge.name), earned" : "\(progress.badge.name), \(progress.progressText)"
    }
}

struct SampleDataBanner: View {
    var body: some View {
        Label("Showing sample data. Turn it off in Settings.", systemImage: "eye")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.frost)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.frost.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
