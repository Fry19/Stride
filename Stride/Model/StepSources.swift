import CoreMotion
import Foundation
import HealthKit
import StrideCore

/// Daily step and distance totals from Apple Health. Steps typed into Health by hand are ignored.
final class HealthSource {
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async throws {
        guard isAvailable else { return }
        let read: Set<HKObjectType> = [stepType, distanceType]
        try await store.requestAuthorization(toShare: [], read: read)
    }

    /// Totals for each day with data. Health doesn't say whether read access was
    /// granted, so a denied request looks the same as no steps.
    func dailyTotals(from first: Day, through last: Day) async throws -> [DayActivity] {
        guard isAvailable else { return [] }
        let start = first.startDate()
        let end = last.adding(days: 1).startDate()
        let steps = try await dailySums(of: stepType, unit: .count(), from: start, to: end)
        let meters = try await dailySums(of: distanceType, unit: .meter(), from: start, to: end)
        return Set(steps.keys).union(meters.keys).map { day in
            DayActivity(day: day, steps: Int((steps[day] ?? 0).rounded()), meters: meters[day] ?? 0)
        }
    }

    private func dailySums(of type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> [Day: Double] {
        let inRange = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let notTypedIn = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyWasUserEntered, operatorType: .notEqualTo, value: true)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: type,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [inRange, notTypedIn])),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1))
        let collection = try await query.result(for: store)

        var sums: [Day: Double] = [:]
        for statistics in collection.statistics() {
            if let sum = statistics.sumQuantity() {
                sums[Day(statistics.startDate)] = sum.doubleValue(for: unit)
            }
        }
        return sums
    }
}

/// The iPhone's own step counter. It remembers about the last 7 days and can update live.
final class MotionSource {
    private let pedometer = CMPedometer()

    private var canCount: Bool {
        CMPedometer.isStepCountingAvailable()
            && ![CMAuthorizationStatus.denied, .restricted].contains(CMPedometer.authorizationStatus())
    }

    /// The first call shows the Motion & Fitness permission prompt.
    func dailyTotals(lastDays count: Int, endingOn today: Day) async -> [DayActivity] {
        guard canCount else { return [] }
        var result: [DayActivity] = []
        for day in today.adding(days: -(count - 1)).through(today) {
            let start = day.startDate()
            let end = min(Date(), day.adding(days: 1).startDate())
            if let data = await query(from: start, to: end) {
                result.append(Self.activity(on: day, from: data))
            }
        }
        return result
    }

    /// Calls `onUpdate` with the running total for `day` as the user walks.
    func startLiveUpdates(for day: Day, onUpdate: @escaping (DayActivity) -> Void) {
        guard canCount else { return }
        pedometer.startUpdates(from: day.startDate()) { data, _ in
            guard let data else { return }
            onUpdate(Self.activity(on: day, from: data))
        }
    }

    func stopLiveUpdates() {
        pedometer.stopUpdates()
    }

    private func query(from start: Date, to end: Date) async -> CMPedometerData? {
        await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func activity(on day: Day, from data: CMPedometerData) -> DayActivity {
        DayActivity(day: day, steps: data.numberOfSteps.intValue, meters: data.distance?.doubleValue ?? 0)
    }
}
