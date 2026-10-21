import Foundation
import StrideCore

struct QuestProgress: Identifiable, Equatable {
    let quest: Quest
    let state: QuestState

    var id: String { quest.id }

    var fraction: Double {
        switch state {
        case .done: return 1
        case .inProgress(let current, let target), .missed(let current, let target):
            return target > 0 ? min(1, Double(current) / Double(target)) : 0
        }
    }

    /// Made-up window counts for sample data: today's steps spread evenly over waking hours.
    static func sampleWindowSteps(today: Day, steps: Int, now: Date) -> [String: Int] {
        let minutesNow = Int(now.timeIntervalSince(today.startDate()) / 60)
        let wakingStart = 7 * 60
        let walkedMinutes = max(1, minutesNow - wakingStart)
        var counts: [String: Int] = [:]
        for quest in Quests.forDay(today) {
            guard let window = quest.window else { continue }
            let overlap = max(0, min(minutesNow, window.upperBound) - max(wakingStart, window.lowerBound))
            counts[quest.id] = steps * overlap / walkedMinutes
        }
        return counts
    }
}
