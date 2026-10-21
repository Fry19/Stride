import AppIntents
import Foundation
import StrideCore

/// Siri phrases, also listed in the Shortcuts app and available for the Action Button.
struct StrideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWalkIntent(), phrases: [
            "Start a walk in \(.applicationName)",
            "Start a \(.applicationName) walk",
            "Go for a walk with \(.applicationName)",
        ], shortTitle: "Start a Walk", systemImageName: "figure.walk")
        AppShortcut(intent: EndWalkIntent(), phrases: [
            "End my walk in \(.applicationName)",
            "Stop my \(.applicationName) walk",
        ], shortTitle: "End Walk", systemImageName: "stop.circle")
        AppShortcut(intent: PauseWalkIntent(), phrases: [
            "Pause my walk in \(.applicationName)",
            "Pause my \(.applicationName) walk",
        ], shortTitle: "Pause Walk", systemImageName: "pause.circle")
        AppShortcut(intent: ResumeWalkIntent(), phrases: [
            "Resume my walk in \(.applicationName)",
            "Resume my \(.applicationName) walk",
        ], shortTitle: "Resume Walk", systemImageName: "play.circle")
        AppShortcut(intent: TodayStepsIntent(), phrases: [
            "How many steps today in \(.applicationName)",
            "Check my steps in \(.applicationName)",
        ], shortTitle: "Today's Steps", systemImageName: "shoeprints.fill")
    }
}

/// Says how many steps you've taken today and how many are left.
struct TodayStepsIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Steps"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        await model.refresh()
        let today = model.summary.todayResult
        let left = max(0, today.goal - today.steps)
        let message = left > 0
            ? "\(today.steps.formatted()) steps so far today, \(left.formatted()) to go."
            : "\(today.steps.formatted()) steps today. Goal reached!"
        return .result(dialog: "\(message)")
    }
}

extension AppModel: WalkIntentRunner {
    func startWalkFromIntent() -> String {
        guard state.hasOnboarded else { return "Open Stride to set it up first." }
        showsWalkScreen = true
        guard !walk.isActive else { return "You're already on a walk." }
        startWalk()
        return "Walk started. Enjoy it!"
    }

    func finishWalkFromIntent() -> String {
        guard walk.isActive else { return "There's no walk in progress." }
        showsWalkScreen = false
        guard let finished = finishWalk() else { return "Walk ended. It was too short to save." }
        let distance = StrideFormat.distance(meters: finished.meters, decimals: 2)
        return "Walk saved: \(finished.steps.formatted()) steps and \(distance) in \(max(1, finished.minutes)) minutes."
    }

    func pauseWalkFromIntent() -> String {
        guard walk.isActive else { return "There's no walk in progress." }
        guard !walk.isPaused else { return "Your walk is already paused." }
        pauseWalk()
        return "Walk paused."
    }

    func resumeWalkFromIntent() -> String {
        guard walk.isActive else { return "There's no walk in progress." }
        guard walk.isPaused else { return "Your walk is already going." }
        resumeWalk()
        return "Walk resumed."
    }
}
