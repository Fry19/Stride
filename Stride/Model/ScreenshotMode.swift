import Foundation
import StrideCore

/// Debug builds launched with `-StrideScreen <screen>` open straight to that screen, filled with
/// sample data and without touching saved data. The screenshots workflow uses this.
/// Screens: today, walk, journey, picker, level, trophies, records, recap, celebration, onboarding.
enum ScreenshotMode {
    static let screen: String? = {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "StrideScreen")
        #else
        return nil
        #endif
    }()

    static var isActive: Bool { screen != nil }

    static var initialTab: AppTab {
        switch screen {
        case "recap", "records": return .trophies
        case "picker": return .journey
        default: return AppTab(rawValue: screen ?? "") ?? .today
        }
    }

    static func state(today: Day) -> SavedState {
        var state = SavedState(startDay: today)
        state.hasOnboarded = screen != "onboarding"
        state.useSampleData = true
        state.goalChanges = [GoalChange(from: today.adding(days: -365), goal: RewardRules.defaultGoal)]
        return state
    }

    /// The latest new-tier level-up, stamp and badge from the sample history, for the celebration screen.
    static func celebration(from summary: RewardSummary) -> [Unlock] {
        guard screen == "celebration" else { return [] }
        func latest(_ matches: (Unlock.Kind) -> Bool) -> Unlock? {
            summary.unlocks.last { matches($0.kind) }
        }
        return [
            latest {
                if case .levelUp(let level, _) = $0 { return Levels.tier(forLevel: level).firstLevel == level }
                return false
            },
            latest { if case .stamp = $0 { return true }; return false },
            latest { if case .badge = $0 { return true }; return false },
        ].compactMap { $0 }
    }
}
