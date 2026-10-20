import Foundation
import StrideCore

/// Debug builds launched with `-StrideScreen <screen>` open straight to that screen, filled with
/// sample data and without touching saved data. The screenshots workflow uses this.
/// Screens: today, journey, passport, rewards, celebration, onboarding.
enum ScreenshotMode {
    static let screen: String? = {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "StrideScreen")
        #else
        return nil
        #endif
    }()

    static var isActive: Bool { screen != nil }

    static var initialTab: AppTab { AppTab(rawValue: screen ?? "") ?? .today }

    static func state(today: Day) -> SavedState {
        var state = SavedState(startDay: today)
        state.hasOnboarded = screen != "onboarding"
        state.useSampleData = true
        state.goalChanges = [GoalChange(from: today.adding(days: -365), goal: RewardRules.defaultGoal)]
        state.rewards = [
            Reward(name: "Fancy coffee", cost: 300),
            Reward(name: "Movie night", cost: 1_200),
            Reward(name: "New walking shoes", cost: 6_000),
        ]
        return state
    }

    /// One stamp, badge and postcard from the sample history, for the celebration screen.
    static func celebration(from summary: RewardSummary) -> [Unlock] {
        guard screen == "celebration" else { return [] }
        func latest(_ matches: (Unlock.Kind) -> Bool) -> Unlock? {
            summary.unlocks.last { matches($0.kind) }
        }
        return [
            latest { if case .stamp = $0 { return true }; return false },
            latest { if case .badge = $0 { return true }; return false },
            latest { if case .stop = $0 { return true }; return false },
        ].compactMap { $0 }
    }
}
