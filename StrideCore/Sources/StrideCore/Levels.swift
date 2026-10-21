import Foundation

/// Every five levels is a tier, and each tier has its own material for the emblem and app icon.
public struct Tier: Identifiable, Hashable {
    public let number: Int
    public let name: String
    public let tagline: String

    public var id: Int { number }
    public var firstLevel: Int { (number - 1) * Levels.levelsPerTier + 1 }
    public var lastLevel: Int { number * Levels.levelsPerTier }
}

public enum Levels {
    public static let maxLevel = 50
    public static let levelsPerTier = 5

    /// Total XP needed to reach `level`. Level 2 takes 2,000 XP, level 6 (tier 2) 50,000,
    /// and level 50 4.8 million, about a year and a half of 8,000-step days.
    public static func xpRequired(for level: Int) -> Int {
        let level = min(max(level, 1), maxLevel)
        return 2_000 * (level - 1) * (level - 1)
    }

    public static func level(forXP xp: Int) -> Int {
        var level = 1
        while level < maxLevel && xp >= xpRequired(for: level + 1) {
            level += 1
        }
        return level
    }

    public static func tier(forLevel level: Int) -> Tier {
        tiers[(min(max(level, 1), maxLevel) - 1) / levelsPerTier]
    }

    public static let tiers: [Tier] = [
        Tier(number: 1, name: "Chalk", tagline: "Where every walker starts."),
        Tier(number: 2, name: "Graphite", tagline: "Matte, dark and understated."),
        Tier(number: 3, name: "Copper", tagline: "Your first metal. It suits you."),
        Tier(number: 4, name: "Bronze", tagline: "Warm, weathered and earned."),
        Tier(number: 5, name: "Steel", tagline: "Brushed steel, built to last."),
        Tier(number: 6, name: "Silver", tagline: "Polished to a mirror shine."),
        Tier(number: 7, name: "Gold", tagline: "Solid gold, one step at a time."),
        Tier(number: 8, name: "Platinum", tagline: "Rarer than gold."),
        Tier(number: 9, name: "Obsidian", tagline: "Volcanic glass with a hidden spectrum."),
        Tier(number: 10, name: "Aurora", tagline: "The northern lights, earned on foot."),
    ]
}

/// Where a total amount of XP puts you.
public struct LevelProgress: Hashable {
    public let xp: Int
    public let level: Int

    public init(xp: Int) {
        self.xp = max(0, xp)
        self.level = Levels.level(forXP: self.xp)
    }

    public var tier: Tier { Levels.tier(forLevel: level) }
    public var isMaxLevel: Bool { level >= Levels.maxLevel }

    public var xpIntoLevel: Int { xp - Levels.xpRequired(for: level) }

    /// XP between this level and the next; 0 at the max level.
    public var xpForLevel: Int {
        isMaxLevel ? 0 : Levels.xpRequired(for: level + 1) - Levels.xpRequired(for: level)
    }

    public var xpToNextLevel: Int {
        isMaxLevel ? 0 : Levels.xpRequired(for: level + 1) - xp
    }

    public var fraction: Double {
        isMaxLevel ? 1 : Double(xpIntoLevel) / Double(xpForLevel)
    }

    /// The next tier and the XP still needed to reach it, or nil at the top tier.
    public var nextTier: (tier: Tier, xpNeeded: Int)? {
        guard tier.number < Levels.tiers.count else { return nil }
        let next = Levels.tiers[tier.number]
        return (next, Levels.xpRequired(for: next.firstLevel) - xp)
    }
}
