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
    /// Time spent moving, leaving out pauses. Missing on walks saved before pausing existed.
    var movingSeconds: TimeInterval?
    /// Moving time for each whole mile or kilometer, `splitMeters` long.
    var splits: [TimeInterval]?
    var splitMeters: Double?
    /// Whether the walk was saved to Apple Health as a workout.
    var savedToHealth: Bool?

    var duration: TimeInterval { movingSeconds ?? end.timeIntervalSince(start) }
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

/// Walk options from Settings.
enum WalkPreferences {
    static let autoPauseKey = "walk.autoPause"
    static let spokenUpdatesKey = "walk.spokenUpdates"
    static let saveToHealthKey = "walk.saveToHealth"

    static var autoPause: Bool { UserDefaults.standard.object(forKey: autoPauseKey) as? Bool ?? true }
    static var spokenUpdates: Bool { UserDefaults.standard.object(forKey: spokenUpdatesKey) as? Bool ?? true }
    static var saveToHealth: Bool { UserDefaults.standard.bool(forKey: saveToHealthKey) }
}

/// Tracks one walk at a time: steps from the pedometer, distance and route from GPS.
/// Location keeps running in the background so the walk keeps counting with the phone locked.
@MainActor
@Observable
final class WalkController: NSObject, CLLocationManagerDelegate {
    /// A walk just ended, with what Apple Health needs to save it as a workout.
    struct Finished {
        let walk: Walk
        let locations: [CLLocation]
        let pauses: [DateInterval]
    }

    private(set) var startDate: Date?
    private(set) var steps = 0
    private(set) var meters: Double = 0
    private(set) var route: [CLLocationCoordinate2D] = []
    private(set) var locationDenied = false
    /// When the walk was paused, by hand or automatically; nil while walking.
    private(set) var pausedAt: Date?
    private(set) var isAutoPaused = false
    /// Time spent in pauses that have ended.
    private(set) var pausedSeconds: TimeInterval = 0
    /// Moving time for each whole mile or kilometer so far.
    private(set) var splits: [TimeInterval] = []

    var isActive: Bool { startDate != nil }
    var isPaused: Bool { pausedAt != nil }

    /// The start moved later by the time spent paused, so a timer counting from it shows moving time.
    var timerStart: Date? { startDate?.addingTimeInterval(pausedSeconds) }

    func movingSeconds(at now: Date = Date()) -> TimeInterval {
        guard let startDate else { return 0 }
        return max(0, (pausedAt ?? now).timeIntervalSince(startDate) - pausedSeconds)
    }

    /// Called when the walk pauses or resumes, so the Live Activity can follow.
    @ObservationIgnored var onPauseChange: (() -> Void)?

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private let voice = WalkVoice()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var pedometerSteps = 0
    @ObservationIgnored private var pedometerMeters: Double = 0
    @ObservationIgnored private var gpsMeters: Double = 0
    @ObservationIgnored private var lastLocation: CLLocation?
    /// Every accurate location while walking, for the route saved to Apple Health.
    @ObservationIgnored private var locations: [CLLocation] = []
    /// Today's displayed steps when the walk began, so live steps can be counted before the pedometer reports.
    @ObservationIgnored private var todayStepsAtStart = 0
    @ObservationIgnored private var todaySteps = 0
    @ObservationIgnored private var goal = 0
    /// Steps and distance taken while paused, left out of the walk.
    @ObservationIgnored private var pausedPedometerSteps = 0
    @ObservationIgnored private var pausedPedometerMeters: Double = 0
    @ObservationIgnored private var pausedTodaySteps = 0
    @ObservationIgnored private var countsAtPause = (pedometerSteps: 0, pedometerMeters: 0.0, todaySteps: 0)
    @ObservationIgnored private var pauses: [DateInterval] = []
    /// The last time a step or GPS movement was seen, for auto-pause.
    @ObservationIgnored private var lastMovement = Date()
    @ObservationIgnored private var highestRawSteps = 0
    @ObservationIgnored private var spokenDistances = 0
    @ObservationIgnored private var spokeHalfway = false
    @ObservationIgnored private var spokeGoal = false

    /// Standing still this long pauses the walk, if auto-pause is on.
    private static let autoPauseAfter: TimeInterval = 25
    private static var voiceInterval: Double { StrideFormat.usesMiles ? 804.672 : 1_000 }
    private static var splitLength: Double { StrideFormat.usesMiles ? 1_609.344 : 1_000 }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func start(todaySteps: Int, goal: Int) {
        guard !isActive else { return }
        let now = Date()
        startDate = now
        steps = 0
        meters = 0
        route = []
        pausedAt = nil
        isAutoPaused = false
        pausedSeconds = 0
        splits = []
        pedometerSteps = 0
        pedometerMeters = 0
        gpsMeters = 0
        lastLocation = nil
        locations = []
        todayStepsAtStart = todaySteps
        self.todaySteps = todaySteps
        self.goal = goal
        pausedPedometerSteps = 0
        pausedPedometerMeters = 0
        pausedTodaySteps = 0
        pauses = []
        lastMovement = now
        highestRawSteps = 0
        spokenDistances = 0
        spokeHalfway = goal > 0 && todaySteps >= goal / 2
        spokeGoal = goal > 0 && todaySteps >= goal

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
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForStop() }
        }
    }

    /// Ends the walk and returns it, or nil if it was too short to keep.
    func finish() -> Finished? {
        guard let startDate else { return nil }
        let end = Date()
        if let pausedAt {
            pauses.append(DateInterval(start: pausedAt, end: max(pausedAt, end)))
        }
        let moving = movingSeconds(at: end)
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil
        let walk = Walk(id: UUID(), start: startDate, end: end, steps: steps, meters: meters,
                        route: Self.simplified(route).map { Walk.Point(latitude: $0.latitude, longitude: $0.longitude) },
                        movingSeconds: moving, splits: splits.isEmpty ? nil : splits, splitMeters: Self.splitLength)
        let finished = Finished(walk: walk, locations: locations, pauses: pauses)
        self.startDate = nil
        pausedAt = nil
        isAutoPaused = false
        locations = []
        return moving >= 60 || steps >= 50 ? finished : nil
    }

    // MARK: - Pausing

    func pause() {
        pause(at: Date(), automatically: false)
    }

    func resume() {
        guard let pausedAt else { return }
        let now = Date()
        pauses.append(DateInterval(start: pausedAt, end: max(pausedAt, now)))
        pausedSeconds += max(0, now.timeIntervalSince(pausedAt))
        pausedPedometerSteps += max(0, pedometerSteps - countsAtPause.pedometerSteps)
        pausedPedometerMeters += max(0, pedometerMeters - countsAtPause.pedometerMeters)
        pausedTodaySteps += max(0, todaySteps - countsAtPause.todaySteps)
        self.pausedAt = nil
        isAutoPaused = false
        // Don't count the distance covered while paused.
        lastLocation = nil
        lastMovement = now
        onPauseChange?()
    }

    private func pause(at date: Date, automatically: Bool) {
        guard isActive, !isPaused else { return }
        pausedAt = date
        isAutoPaused = automatically
        countsAtPause = (pedometerSteps, pedometerMeters, todaySteps)
        onPauseChange?()
    }

    /// Auto-pauses after standing still for a while. The pause starts when movement stopped.
    private func checkForStop() {
        guard let startDate, !isPaused, WalkPreferences.autoPause else { return }
        let now = Date()
        guard now.timeIntervalSince(lastMovement) >= Self.autoPauseAfter,
              now.timeIntervalSince(startDate) >= 30 else { return }
        pause(at: lastMovement, automatically: true)
        voice.say("Walk paused.")
    }

    private func noteMovement() {
        lastMovement = Date()
        if isAutoPaused {
            resume()
            voice.say("Walk resumed.")
        }
    }

    // MARK: - Counting

    /// Called as today's live step count rises, so the walk counts steps the moment they happen.
    func noteTodaySteps(_ count: Int, goal: Int) {
        guard isActive, !ScreenshotMode.isActive else { return }
        todaySteps = count
        self.goal = goal
        checkForSteps()
        updateTotals()
        announceGoal()
    }

    private func applyPedometer(steps: Int, meters: Double) {
        guard isActive else { return }
        pedometerSteps = steps
        pedometerMeters = meters
        checkForSteps()
        updateTotals()
    }

    private func checkForSteps() {
        let raw = max(pedometerSteps, todaySteps - todayStepsAtStart)
        guard raw > highestRawSteps else { return }
        highestRawSteps = raw
        noteMovement()
    }

    private func updateTotals() {
        guard !isPaused else { return }
        steps = max(steps, pedometerSteps - pausedPedometerSteps, todaySteps - todayStepsAtStart - pausedTodaySteps)
        // GPS is the better measure of distance outdoors; the pedometer covers indoors and gaps.
        meters = max(meters, gpsMeters, pedometerMeters - pausedPedometerMeters)
        recordSplits()
    }

    private func recordSplits() {
        while meters >= Double(splits.count + 1) * Self.splitLength {
            splits.append(max(0, movingSeconds() - splits.reduce(0, +)))
        }
        let reached = Int(meters / Self.voiceInterval)
        if reached > spokenDistances {
            spokenDistances = reached
            voice.say(WalkVoice.distanceUpdate(intervals: reached, movingSeconds: movingSeconds(), meters: meters, steps: steps))
        }
    }

    private func announceGoal() {
        guard goal > 0 else { return }
        if !spokeGoal && todaySteps >= goal {
            spokeGoal = true
            spokeHalfway = true
            voice.say("Goal reached! \(todaySteps.formatted()) steps today.")
        } else if !spokeHalfway && todaySteps >= goal / 2 {
            spokeHalfway = true
            voice.say("Halfway to your goal. \((goal - todaySteps).formatted()) steps to go.")
        }
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

    private func add(_ newLocations: [CLLocation]) {
        guard isActive else { return }
        for location in newLocations {
            // Walking pace by GPS counts as moving, for auto-pause.
            if location.speed > 0.8 && location.horizontalAccuracy <= 20 {
                noteMovement()
            }
            guard !isPaused else { continue }
            if let last = lastLocation {
                let step = location.distance(from: last)
                guard step >= 3 else { continue }
                gpsMeters += step
            }
            lastLocation = location
            route.append(location.coordinate)
            locations.append(location)
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

    #if DEBUG
    /// Most of a lap of the Central Park Reservoir, for screenshots.
    func showSample() {
        route = SampleData.reservoirLap(points: 35).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        startDate = Date().addingTimeInterval(-21.5 * 60)
        steps = 2_330
        meters = 1_733
        splits = StrideFormat.usesMiles ? [1_190] : [744]
    }
    #endif

    /// The walk in progress, for the Live Activity.
    var activityInfo: StrideActivityAttributes.ContentState.Walk? {
        timerStart.map {
            StrideActivityAttributes.ContentState.Walk(startedAt: $0, steps: steps, meters: meters, pausedAt: pausedAt)
        }
    }
}
