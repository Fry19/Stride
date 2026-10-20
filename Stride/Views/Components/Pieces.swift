import StrideCore
import SwiftUI

/// Progress toward the daily goal. Dots mark every 1,000 steps; a gold inner lap shows steps past the goal.
struct StepRing: View {
    let steps: Int
    let goal: Int
    var lineWidth: CGFloat = 20

    private var fraction: Double { goal > 0 ? Double(steps) / Double(goal) : 0 }
    private var markers: Int { min(goal / 1_000, 40) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blaze.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(fraction, 1))
                .stroke(Color.blaze, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                ForEach(1..<max(markers, 1), id: \.self) { index in
                    Circle()
                        .fill(Color(.systemBackground).opacity(0.8))
                        .frame(width: 4, height: 4)
                        .offset(y: -(side - lineWidth) / 2)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .rotationEffect(.degrees(Double(index) / Double(markers) * 360))
                }
            }
            if fraction > 1 {
                Circle()
                    .trim(from: 0, to: min(fraction - 1, 1))
                    .stroke(Color.coin, style: StrokeStyle(lineWidth: lineWidth * 0.4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth * 1.2)
            }
        }
        .animation(.spring(duration: 0.6), value: steps)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(steps.formatted()) of \(goal.formatted()) steps")
    }
}

struct CoinIcon: View {
    var size: CGFloat = 16

    var body: some View {
        Circle()
            .fill(Color.coin.gradient)
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: max(1, size * 0.09))
                    .padding(size * 0.2)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct CoinAmount: View {
    let value: Int
    var prefix = ""
    var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 5) {
            CoinIcon(size: iconSize)
            Text(prefix + value.formatted())
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prefix + StrideFormat.coins(value))
    }
}

struct StatTile<Icon: View>: View {
    let label: String
    let value: String
    @ViewBuilder var icon: Icon

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            icon
                .font(.title3)
                .frame(height: 22)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The round emblem for a badge: filled when earned, dashed outline when not.
struct BadgeEmblem: View {
    let badge: Badge
    let isUnlocked: Bool
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            if isUnlocked {
                Circle().fill(Color.blaze.gradient)
            } else {
                Circle().fill(Color.secondary.opacity(0.1))
                Circle().strokeBorder(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            Image(systemName: badge.symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(isUnlocked ? Color.white : Color.secondary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct BadgeTile: View {
    let progress: BadgeProgress

    var body: some View {
        VStack(spacing: 8) {
            BadgeEmblem(badge: progress.badge, isUnlocked: progress.isUnlocked)
            Text(progress.badge.name)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            if progress.isUnlocked {
                CoinAmount(value: progress.badge.bonus, prefix: "+", iconSize: 12)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView(value: progress.fraction)
                    .tint(Color.blaze)
                    .frame(height: 12)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .foregroundStyle(Color.frost)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.frost.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
