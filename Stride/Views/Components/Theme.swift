import StrideCore
import SwiftUI
import UIKit

extension Color {
    /// Trail-blaze orange, the app's accent.
    static let blaze = Color(light: 0xD4521D, dark: 0xFF7D45)
    static let coin = Color(light: 0xB8860B, dark: 0xF2C14E)
    static let pine = Color(light: 0x2F5D4A, dark: 0x8FC7AA)
    static let frost = Color(light: 0x2C7BB6, dark: 0x7CC3F0)

    /// Ink colors for passport stamps.
    static let stampInks: [Color] = [
        Color(light: 0x2B59A8, dark: 0x8AABF2),
        Color(light: 0xB3303A, dark: 0xF2858C),
        Color(light: 0x2D7A53, dark: 0x72CC9E),
        Color(light: 0x6B3FA0, dark: 0xBA97EE),
    ]

    static func route(_ id: String) -> Color {
        switch id {
        case "inca": return Color(light: 0x9A4A2C, dark: 0xE08A68)
        case "hadrian": return Color(light: 0x4A5D52, dark: 0xA3BDAE)
        default: return Color(light: 0x1F4E8C, dark: 0x7FA8E6)
        }
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

extension View {
    /// The rounded panel used for sections on scrolling screens.
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

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

    static func coins(_ count: Int) -> String {
        count == 1 ? "1 coin" : "\(count.formatted()) coins"
    }

    static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count.formatted()) days"
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
