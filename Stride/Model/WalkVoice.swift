import AVFoundation
import Foundation

/// Speaks walk updates. Music and podcasts dip or pause while it talks, then carry on.
@MainActor
final class WalkVoice: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String) {
        guard WalkPreferences.spokenUpdates else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt,
                                    options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
        } catch {
            print("Couldn't start speaking: \(error)")
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// "1.5 miles. Time, 28 minutes, 10 seconds. Average pace, 18 minutes, 47 seconds per mile. 3,410 steps."
    static func distanceUpdate(intervals: Int, movingSeconds: TimeInterval, meters: Double, steps: Int) -> String {
        let miles = StrideFormat.usesMiles
        let distance = Double(intervals) * (miles ? 0.5 : 1)
        let unit = miles ? "mile" : "kilometer"
        let distanceText = miles && intervals == 1
            ? "Half a mile"
            : "\(distance.formatted(.number.precision(.fractionLength(0...1)))) \(distance == 1 ? unit : unit + "s")"
        let unitMeters = miles ? 1_609.344 : 1_000
        let pace = movingSeconds / max(meters / unitMeters, 0.01)
        return "\(distanceText). Time, \(spoken(movingSeconds)). Average pace, \(spoken(pace)) per \(unit). \(steps.formatted()) steps."
    }

    private static func spoken(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        return formatter.string(from: seconds.rounded()) ?? ""
    }
}
