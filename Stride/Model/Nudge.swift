import Foundation
import StrideCore
import UserNotifications

/// The evening reminder when today's goal isn't met yet. Tonight's says how far there is to go;
/// the next two evenings get a general one in case Stride doesn't run before then.
enum Nudge {
    static let enabledKey = "nudge.enabled"
    static let minutesKey = "nudge.minutes"
    private static let identifiers = (0..<3).map { "stride.nudge.\($0)" }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    /// Minutes after midnight, 7:30 PM unless changed.
    static var minutes: Int { UserDefaults.standard.object(forKey: minutesKey) as? Int ?? 19 * 60 + 30 }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(today: DayResult, streak: Int, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard isEnabled else { return }
        for (offset, identifier) in identifiers.enumerated() {
            let day = today.day.adding(days: offset)
            guard let fire = Calendar.current.date(byAdding: .minute, value: minutes, to: day.startDate()),
                  fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.sound = .default
            if offset == 0 {
                guard !today.goalMet else { continue }
                let left = today.goal - today.steps
                // About 100 steps a minute at a normal walking pace.
                let walkMinutes = max(5, Int((Double(left) / 100 / 5).rounded(.up)) * 5)
                content.title = "\(left.formatted()) steps to go"
                content.body = streak > 0
                    ? "About \(walkMinutes) minutes of walking keeps your \(streak)-day streak going."
                    : "About \(walkMinutes) minutes of walking gets you to today's goal."
            } else {
                content.title = "How's today going?"
                content.body = "An evening walk could close out today's goal. Open Stride to see how close you are."
            }
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(
                identifier: identifier, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }
}
