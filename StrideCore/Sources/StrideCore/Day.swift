import Foundation

/// A calendar day. Created from a date in the user's calendar, then compared
/// and stepped through without any time zone involved.
public struct Day: Hashable, Comparable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar` (the user's calendar by default).
    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// Parses "yyyy-MM-dd".
    public init?(id: String) {
        let parts = id.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    /// "yyyy-MM-dd"
    public var id: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public var description: String { id }

    /// Midnight at the start of this day in `calendar`.
    public func startDate(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days count: Int) -> Day {
        Day(Day.utc.date(byAdding: .day, value: count, to: utcDate)!, calendar: Day.utc)
    }

    /// Whole days from `self` to `other`; negative when `other` is earlier.
    public func days(until other: Day) -> Int {
        Day.utc.dateComponents([.day], from: utcDate, to: other.utcDate).day!
    }

    /// Every day from `self` through `last`, inclusive. Empty when `last` is earlier.
    public func through(_ last: Day) -> [Day] {
        guard self <= last else { return [] }
        return (0...days(until: last)).map { adding(days: $0) }
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private var utcDate: Date { startDate(in: Day.utc) }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // Stored as "yyyy-MM-dd" so the saved file stays readable.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let day = Day(id: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected yyyy-MM-dd, got \(raw)")
        }
        self = day
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}
