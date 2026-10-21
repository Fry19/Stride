import AppIntents
import Foundation

/// What the walk intents need from the app. The app plugs itself in at launch. The widget
/// extension only uses these intents to draw buttons; iOS runs them in the app.
@MainActor
protocol WalkIntentRunner: AnyObject {
    func startWalkFromIntent() -> String
    func finishWalkFromIntent() -> String
    func pauseWalkFromIntent() -> String
    func resumeWalkFromIntent() -> String
}

@MainActor
enum WalkIntents {
    static weak var runner: WalkIntentRunner?

    static let notRunning = "Open Stride and try again."
}

/// Starts a walk and opens Stride on it. Works from Siri, Shortcuts, the Action Button and Control Center.
struct StartWalkIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Walk"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = WalkIntents.runner?.startWalkFromIntent() ?? WalkIntents.notRunning
        return .result(dialog: "\(message)")
    }
}

/// Ends the walk in progress and saves it.
struct EndWalkIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Walk"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = WalkIntents.runner?.finishWalkFromIntent() ?? WalkIntents.notRunning
        return .result(dialog: "\(message)")
    }
}

struct PauseWalkIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause Walk"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = WalkIntents.runner?.pauseWalkFromIntent() ?? WalkIntents.notRunning
        return .result(dialog: "\(message)")
    }
}

struct ResumeWalkIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume Walk"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = WalkIntents.runner?.resumeWalkFromIntent() ?? WalkIntents.notRunning
        return .result(dialog: "\(message)")
    }
}
