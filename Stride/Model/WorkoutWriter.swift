import CoreLocation
import Foundation
import HealthKit

/// Saves finished walks to Apple Health as walking workouts, with their route.
final class WorkoutWriter {
    private let store = HKHealthStore()

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKSeriesType.workoutRoute(), HKQuantityType(.distanceWalkingRunning)]
    }

    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: [])
    }

    var isAllowed: Bool {
        HKHealthStore.isHealthDataAvailable()
            && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    func save(_ finished: WalkController.Finished) async throws {
        let walk = finished.walk
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = finished.locations.isEmpty ? .unknown : .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: walk.start)
        if walk.meters > 0 {
            let distance = HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: walk.meters),
                start: walk.start, end: walk.end)
            try await builder.addSamples([distance])
        }
        let events = finished.pauses.flatMap { pause in
            [HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil),
             HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil)]
        }
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }
        try await builder.endCollection(at: walk.end)
        guard let workout = try await builder.finishWorkout() else { return }

        guard !finished.locations.isEmpty else { return }
        let route = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        try await route.insertRouteData(finished.locations)
        _ = try await route.finishRoute(with: workout, metadata: nil)
    }
}
