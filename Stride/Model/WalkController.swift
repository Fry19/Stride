import ActivityKit
import CoreLocation
import CoreMotion
import Foundation
import Observation

/// A finished walk.
struct Walk: Codable, Identifiable, Hashable {
    struct Point: Codable, Hashable {
        var latitude: Double
        var longitude: Double
    }

    var id: UUID
    var start: Date
    var end: Date
    var steps: Int
    var meters: Double
    var route: [Point]

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var minutes: Int { Int(duration / 60) }
}

enum WalkStore {
    private static var file: URL { URL.applicationSupportDirectory.appending(path: "stride-walks.json") }

    static func load() -> [Walk] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([Walk].self, from: data)) ?? []
    }

    static func save(_ walks: [Walk]) {
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(walks).write(to: file, options: .atomic)
        } catch {
            print("Couldn't save walks: \(error)")
        }
    }
}

/// Tracks one walk at a time: steps from the pedometer, distance and route from GPS, and a
/// Live Activity on the Lock Screen. Location keeps running in the background so the walk
/// keeps counting with the phone locked.
@MainActor
@Observable
final class WalkController: NSObject, CLLocationManagerDelegate {
    private(set) var startDate: Date?
    private(set) var steps = 0
    private(set) var meters: Double = 0
    private(set) var route: [CLLocationCoordinate2D] = []
    private(set) var locationDenied = false

    var isActive: Bool { startDate != nil }

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private var pedometerSteps = 0
    @ObservationIgnored private var pedometerMeters: Double = 0
    @ObservationIgnored private var gpsMeters: Double = 0
    @ObservationIgnored private var lastLocation: CLLocation?
    /// Today's displayed steps when the walk began, so live steps can be counted before the pedometer reports.
    @ObservationIgnored private var todayStepsAtStart = 0
    @ObservationIgnored private var todaySteps = 0
    @ObservationIgnored private var goal = 8_000
    @ObservationIgnored private var activity: Activity<WalkActivityAttributes>?
    @ObservationIgnored private var activityUpdatedAt = Date.distantPast

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func start(todaySteps: Int, goal: Int, level: Int) {
        guard !isActive else { return }
        let now = Date()
        startDate = now
        steps = 0
        meters = 0
        route = []
        pedometerSteps = 0
        pedometerMeters = 0
        gpsMeters = 0
        lastLocation = nil
        todayStepsAtStart = todaySteps
        self.todaySteps = todaySteps
        self.goal = goal

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
        default:
            break
        }
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()

        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: now) { @Sendable [weak self] data, _ in
                guard let data else { return }
                let steps = data.numberOfSteps.intValue
                let meters = data.distance?.doubleValue ?? 0
                Task { @MainActor in self?.applyPedometer(steps: steps, meters: meters) }
            }
        }
        startActivity(level: level)
    }

    /// Ends the walk and returns it, or nil if it was too short to keep.
    func finish() -> Walk? {
        guard let startDate else { return nil }
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        pedometer.stopUpdates()
        let end = Date()
        let walk = Walk(id: UUID(), start: startDate, end: end, steps: steps, meters: meters,
                        route: Self.simplified(route).map { Walk.Point(latitude: $0.latitude, longitude: $0.longitude) })
        endActivity()
        self.startDate = nil
        return end.timeIntervalSince(startDate) >= 60 || steps >= 50 ? walk : nil
    }

    /// Called as today's live step count rises, so the walk counts steps the moment they happen.
    func noteTodaySteps(_ count: Int) {
        guard isActive else { return }
        todaySteps = count
        updateTotals()
    }

    private func applyPedometer(steps: Int, meters: Double) {
        guard isActive else { return }
        pedometerSteps = steps
        pedometerMeters = meters
        updateTotals()
    }

    private func updateTotals() {
        steps = max(steps, pedometerSteps, todaySteps - todayStepsAtStart)
        // GPS is the better measure of distance outdoors; the pedometer covers indoors and gaps.
        meters = max(gpsMeters, pedometerMeters)
        updateActivityIfDue()
    }

    // MARK: - Location

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let accurate = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 30 }
        Task { @MainActor in self.add(accurate) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.locationDenied = status == .denied || status == .restricted
        }
    }

    private func add(_ locations: [CLLocation]) {
        guard isActive else { return }
        for location in locations {
            if let last = lastLocation {
                let step = location.distance(from: last)
                guard step >= 3 else { continue }
                gpsMeters += step
            }
            lastLocation = location
            route.append(location.coordinate)
        }
        updateTotals()
    }

    /// Keeps the saved route small: a point at least every 15 m.
    private static func simplified(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        var kept: [CLLocationCoordinate2D] = []
        var last: CLLocation?
        for point in points {
            let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
            if let last, location.distance(from: last) < 15 { continue }
            kept.append(point)
            last = location
        }
        if let final = points.last, kept.last.map({ $0.latitude != final.latitude || $0.longitude != final.longitude }) ?? true {
            kept.append(final)
        }
        return kept
    }

    // MARK: - Live Activity

    private var activityState: WalkActivityAttributes.ContentState {
        WalkActivityAttributes.ContentState(
            steps: steps, meters: meters, todaySteps: max(todaySteps, todayStepsAtStart + steps), goal: goal,
            usesMiles: Locale.current.measurementSystem == .us)
    }

    private func startActivity(level: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let startDate else { return }
        let attributes = WalkActivityAttributes(startedAt: startDate, level: level)
        activity = try? Activity.request(attributes: attributes,
                                         content: ActivityContent(state: activityState, staleDate: nil),
                                         pushType: nil)
        activityUpdatedAt = Date()
    }

    /// Updates at most every few seconds; the timer on the Lock Screen runs on its own.
    private func updateActivityIfDue() {
        guard let activity, Date().timeIntervalSince(activityUpdatedAt) >= 4 else { return }
        activityUpdatedAt = Date()
        let content = ActivityContent(state: activityState, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endActivity() {
        guard let activity else { return }
        let content = ActivityContent(state: activityState, staleDate: nil)
        self.activity = nil
        Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(15 * 60))) }
    }
}
