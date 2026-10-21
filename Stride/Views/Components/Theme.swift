import StrideCore
import SwiftUI

/// Stride's look: near-black backgrounds lit by the color of your current tier,
/// frosted glass panels, and warm gradients for progress.
enum Theme {
    static let background = Color(hex: 0x050507)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)
    static let hairline = Color.white.opacity(0.09)

    static let ember = Color(hex: 0xFF6A2B)
    static let live = Color(hex: 0x3DFF8A)
    static let frost = Color(hex: 0x7CC8FF)

    /// Step ring before the goal is met.
    static let ringColors = [Color(hex: 0xFFC247), Color(hex: 0xFF6A2B), Color(hex: 0xFF2E6E)]
    /// Step ring once the goal is met.
    static let goldColors = [Color(hex: 0xFFF1B0), Color(hex: 0xFFC94A), Color(hex: 0xF0962A)]
    /// XP bars.
    static let xpColors = [Color(hex: 0x7CF3FF), Color(hex: 0x8A7CFF), Color(hex: 0xFF6AD5)]
    /// Buttons.
    static let buttonColors = [Color(hex: 0xFF8A3D), Color(hex: 0xFF3D6E)]

    /// Ink colors for passport stamps.
    static let stampInks = [Color(hex: 0x8AB0FF), Color(hex: 0xFF8A93), Color(hex: 0x72E0A6), Color(hex: 0xC59BFF)]
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    static func route(_ id: String) -> Color {
        switch id {
        case "inca": return Color(hex: 0xFF8A5C)
        case "hadrian": return Color(hex: 0x8FD3B0)
        default: return Color(hex: 0x7FA8FF)
        }
    }
}

extension Tier {
    /// The glow color of this tier's material.
    var color: Color {
        switch number {
        case 1: return Color(hex: 0xEDEAE3)
        case 2: return Color(hex: 0x9097A3)
        case 3: return Color(hex: 0xE58E5E)
        case 4: return Color(hex: 0xC9A06A)
        case 5: return Color(hex: 0xA9B6C4)
        case 6: return Color(hex: 0xE4E9F0)
        case 7: return Color(hex: 0xF2C14E)
        case 8: return Color(hex: 0xDCE6F4)
        case 9: return Color(hex: 0xA88CFF)
        default: return Color(hex: 0x5CF2D0)
        }
    }

    var emblemName: String { "Emblem\(number)" }

    var levelRange: String { "Levels \(firstLevel)–\(lastLevel)" }
}

// MARK: - Surfaces

/// A frosted glass panel.
struct Glass: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.085), Color.white.opacity(0.035)],
                                         startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
    }
}

extension View {
    func glass(radius: CGFloat = 24, padding: CGFloat = 18) -> some View {
        modifier(Glass(radius: radius, padding: padding))
    }
}

/// Black, lit from the top by `glow`.
struct ScreenBackground: View {
    var glow: Color

    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [glow.opacity(0.30), .clear],
                           center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Theme.ember.opacity(0.10), .clear],
                           center: UnitPoint(x: 1.05, y: 0.55), startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.textTertiary)
    }
}

/// The title block at the top of each tab.
struct ScreenHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    SectionLabel(text: eyebrow)
                }
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            trailing
        }
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: String?, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(LinearGradient(colors: Theme.buttonColors, startPoint: .leading, endPoint: .trailing),
                        in: Capsule())
            .shadow(color: Theme.buttonColors[1].opacity(0.45), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A round frosted button holding an SF Symbol.
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Formatting

enum StrideFormat {
    static var usesMiles: Bool { Locale.current.measurementSystem == .us }

    static func distance(km: Double, decimals: Int = 1) -> String {
        let value = usesMiles ? km / 1.609344 : km
        return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(usesMiles ? "mi" : "km")"
    }

    static func distance(meters: Double, decimals: Int = 1) -> String {
        distance(km: meters / 1000, decimals: decimals)
    }

    static func date(_ day: Day) -> String {
        day.startDate().formatted(.dateTime.month(.abbreviated).day())
    }

    static func longDate(_ day: Day) -> String {
        day.startDate().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    static func xp(_ amount: Int) -> String {
        "\(amount.formatted()) XP"
    }
}

extension BadgeProgress {
    var progressText: String {
        let current = Int(value)
        let target = Int(badge.target)
        switch badge.metric {
        case .daysWalked:
            return "\(current) of \(target) days walked"
        case .goalDays:
            return "\(current) of \(target) goal days"
        case .bestStreak:
            return "Best streak: \(current) of \(target) days"
        case .bestDaySteps:
            return "Best day: \(current.formatted()) of \(target.formatted()) steps"
        case .lifetimeSteps:
            return "\(current.formatted()) of \(target.formatted()) steps"
        case .lifetimeMeters:
            return "\(StrideFormat.distance(meters: value)) of \(StrideFormat.distance(meters: badge.target))"
        }
    }
}
