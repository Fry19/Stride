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

/// Counts steps from the accelerometer the moment they happen. The pedometer is more accurate
/// but only reports every few seconds, so these steps fill the gap until its next report.
final class StepDetector {
    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "StepDetector"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // Only touched on `queue`.
    private var smoothed = 0.0
    private var isAboveThreshold = false
    private var lastStepTime: TimeInterval = 0
    private var stepsInRhythm = 0
    private var heldSteps = 0

    /// Bounce needed to count as a step, in g.
    private static let threshold = 0.08
    /// Steps closer together than this are noise.
    private static let minimumGap: TimeInterval = 0.25
    /// A longer pause means the walk stopped.
    private static let maximumGap: TimeInterval = 1.6
    /// Steps are held back until this many arrive at a walking rhythm, so picking up
    /// or tapping the phone doesn't count.
    private static let stepsToConfirm = 4

    func start(onStep: @escaping () -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            for _ in 0..<self.stepsCounted(in: motion) {
                onStep()
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func stepsCounted(in motion: CMDeviceMotion) -> Int {
        // Acceleration along gravity: the up-and-down bounce of each step.
        let acceleration = motion.userAcceleration
        let gravity = motion.gravity
        let vertical = acceleration.x * gravity.x + acceleration.y * gravity.y + acceleration.z * gravity.z
        smoothed += (vertical - smoothed) * 0.3

        if isAboveThreshold {
            if smoothed < Self.threshold * 0.3 { isAboveThreshold = false }
            return 0
        }
        guard smoothed > Self.threshold else { return 0 }
        isAboveThreshold = true

        let gap = motion.timestamp - lastStepTime
        guard gap > Self.minimumGap else { return 0 }
        lastStepTime = motion.timestamp
        if gap > Self.maximumGap {
            stepsInRhythm = 0
            heldSteps = 0
        }
        stepsInRhythm += 1
        if stepsInRhythm < Self.stepsToConfirm {
            heldSteps += 1
            return 0
        }
        let count = heldSteps + 1
        heldSteps = 0
        return count
    }
}
