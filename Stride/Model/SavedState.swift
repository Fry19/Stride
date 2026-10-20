import Foundation
import StrideCore

/// Everything Stride keeps on the phone. Step history is also cached here so
/// days older than the motion sensor's 7-day memory aren't lost.
struct SavedState: Codable {
    var startDay: Day
    var hasOnboarded = false
    var goalChanges: [GoalChange] = []
    var rewards: [Reward] = []
    var redemptions: [Redemption] = []
    var activity: [DayActivity] = []
    /// Ids of unlocks already celebrated.
    var celebrated: Set<String> = []
    var useSampleData = false

    init(startDay: Day) {
        self.startDay = startDay
    }

    // Decoded field by field so files saved by older versions still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDay = try container.decode(Day.self, forKey: .startDay)
        hasOnboarded = try container.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
        goalChanges = try container.decodeIfPresent([GoalChange].self, forKey: .goalChanges) ?? []
        rewards = try container.decodeIfPresent([Reward].self, forKey: .rewards) ?? []
        redemptions = try container.decodeIfPresent([Redemption].self, forKey: .redemptions) ?? []
        activity = try container.decodeIfPresent([DayActivity].self, forKey: .activity) ?? []
        celebrated = try container.decodeIfPresent(Set<String>.self, forKey: .celebrated) ?? []
        useSampleData = try container.decodeIfPresent(Bool.self, forKey: .useSampleData) ?? false
    }
}

enum StateStore {
    private static var folder: URL { URL.applicationSupportDirectory }
    private static var file: URL { folder.appending(path: "stride-state.json") }

    static func load() -> SavedState? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        do {
            return try JSONDecoder().decode(SavedState.self, from: data)
        } catch {
            // Keep the unreadable file instead of silently overwriting it.
            try? data.write(to: folder.appending(path: "stride-state-unreadable.json"), options: .atomic)
            print("Couldn't read saved state: \(error)")
            return nil
        }
    }

    static func save(_ state: SavedState) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: file, options: .atomic)
        } catch {
            print("Couldn't save state: \(error)")
        }
    }
}
