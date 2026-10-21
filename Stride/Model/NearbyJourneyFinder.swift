import CoreLocation
import Foundation
import MapKit
import Observation
import StrideCore

/// A journey to a real place near the user, along an actual walking route.
struct NearbySuggestion: Identifiable, Equatable {
    let route: Route
    /// SF Symbol for the kind of place.
    let symbol: String
    let kind: String

    var id: String { route.id }
}

/// Finds places around the user (parks, landmarks, museums, lakes, beaches and bigger trips
/// further out) and plans a walking route to each with Apple Maps.
@MainActor
@Observable
final class NearbyJourneyFinder: NSObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case idle
        case locating
        case searching
        case ready
        case needsPermission
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var suggestions: [NearbySuggestion] = []

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var waitingForLocation: CheckedContinuation<CLLocation?, Never>?

    /// What to look for, and how far out.
    private static let searches: [(query: String, radiusKm: Double)] = [
        ("park", 5), ("landmark", 12), ("museum", 15), ("lake", 25),
        ("beach", 40), ("state park", 60), ("national park", 90),
    ]
    /// Straight-line distance bands, so the suggestions range from an afternoon to a few weeks.
    private static let bands: [ClosedRange<Double>] = [1...4, 4...10, 10...25, 25...90]

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isWorking: Bool { status == .locating || status == .searching }

    /// Whether location access is already granted, so searching won't show a prompt.
    var hasPermission: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus)
    }

    func find() async {
        guard !isWorking else { return }
        if [.denied, .restricted].contains(manager.authorizationStatus) {
            status = .needsPermission
            return
        }
        status = .locating
        guard let here = await currentLocation() else {
            status = [.denied, .restricted].contains(manager.authorizationStatus)
                ? .needsPermission
                : .failed("Stride couldn't find where you are. Try again outside or with Wi-Fi on.")
            return
        }

        status = .searching
        let places = await searchPlaces(around: here.coordinate)
        var found: [NearbySuggestion] = []
        for place in Self.pick(places, from: here) {
            if let suggestion = await planWalk(to: place, from: here) {
                found.append(suggestion)
            }
        }
        suggestions = found.sorted { $0.route.lengthKm < $1.route.lengthKm }
        status = found.isEmpty ? .failed("No walking routes turned up nearby. Try again later.") : .ready
    }

    // MARK: - Location

    private func currentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            waitingForLocation = continuation
            if manager.authorizationStatus == .notDetermined {
                // The location is requested once permission is given.
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finishLocating(_ location: CLLocation?) {
        waitingForLocation?.resume(returning: location)
        waitingForLocation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finishLocating(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finishLocating(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.waitingForLocation != nil else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                self.finishLocating(nil)
            default:
                break
            }
        }
    }

    // MARK: - Places

    private func searchPlaces(around center: CLLocationCoordinate2D) async -> [MKMapItem] {
        var items: [MKMapItem] = []
        var names = Set<String>()
        for search in Self.searches {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = search.query
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: search.radiusKm * 2_000,
                                                longitudinalMeters: search.radiusKm * 2_000)
            guard let response = try? await MKLocalSearch(request: request).start() else { continue }
            for item in response.mapItems {
                guard let name = item.name, names.insert(name).inserted else { continue }
                items.append(item)
            }
        }
        return items
    }

    /// Up to two places per distance band, preferring different kinds of place.
    private static func pick(_ items: [MKMapItem], from here: CLLocation) -> [MKMapItem] {
        var picked: [MKMapItem] = []
        for band in bands {
            var kinds = Set<String>()
            let inBand = items
                .map { (item: $0, km: here.distance(from: CLLocation(latitude: $0.placemark.coordinate.latitude,
                                                                      longitude: $0.placemark.coordinate.longitude)) / 1_000) }
                .filter { band.contains($0.km) }
                .sorted { $0.km < $1.km }
            for candidate in inBand where picked.count < bands.count * 2 {
                let kind = describe(candidate.item.pointOfInterestCategory).kind
                guard !kinds.contains(kind) else { continue }
                kinds.insert(kind)
                picked.append(candidate.item)
                if kinds.count == 2 { break }
            }
        }
        return picked
    }

    private func planWalk(to place: MKMapItem, from here: CLLocation) async -> NearbySuggestion? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: here.coordinate))
        request.destination = place
        request.transportType = .walking
        guard let walk = try? await MKDirections(request: request).calculate().routes.first,
              walk.distance > 500 else { return nil }

        let points = Self.coordinates(of: walk.polyline)
        guard let first = points.first, let last = points.last else { return nil }
        let km = walk.distance / 1_000
        let name = place.name ?? "Somewhere new"
        let (symbol, kind) = Self.describe(place.pointOfInterestCategory)

        var stops = [Stop(id: "start", name: "Start", km: 0, fact: "Where you set off from.",
                          latitude: first.latitude, longitude: first.longitude)]
        stops += Self.checkpoints(along: walk)
        stops.append(Stop(id: "destination", name: name, km: km,
                          fact: "\(kind), about \(StrideFormat.distance(km: km)) on foot from where you started.",
                          latitude: last.latitude, longitude: last.longitude))

        let id = "nearby.\(Int(Date().timeIntervalSince1970)).\(abs(name.hashValue) % 100_000)"
        let route = Route(
            id: id, name: name, region: place.placemark.locality.map { "Near you · \($0)" } ?? "Near you",
            stops: stops.map { Stop(id: "\(id).\($0.id)", name: $0.name, km: $0.km, fact: $0.fact,
                                    latitude: $0.latitude, longitude: $0.longitude) },
            path: Self.thinned(points).map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) })
        return NearbySuggestion(route: route, symbol: symbol, kind: kind)
    }

    /// Checkpoints named after the streets and paths along the way: one on a short walk, up to three on a long one.
    private static func checkpoints(along walk: MKRoute) -> [Stop] {
        let total = walk.distance
        let count = total < 3_000 ? 1 : total < 15_000 ? 2 : 3
        let targets = (1...count).map { total * Double($0) / Double(count + 1) }
        var stops: [Stop] = []
        var covered = 0.0
        var targetIndex = 0
        for step in walk.steps {
            while targetIndex < targets.count && covered + step.distance >= targets[targetIndex] {
                let point = step.polyline.coordinate
                let street = streetName(in: step.instructions) ?? "Checkpoint \(targetIndex + 1)"
                stops.append(Stop(id: "checkpoint\(targetIndex + 1)", name: street, km: targets[targetIndex] / 1_000,
                                  fact: "\(StrideFormat.distance(km: targets[targetIndex] / 1_000)) along the way.",
                                  latitude: point.latitude, longitude: point.longitude))
                targetIndex += 1
            }
            covered += step.distance
        }
        return stops
    }

    /// "Turn right onto Market St" → "Market St".
    private static func streetName(in instructions: String) -> String? {
        for marker in [" onto ", " on ", " toward ", " towards "] {
            if let range = instructions.range(of: marker) {
                let name = instructions[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
        }
        return nil
    }

    private static func coordinates(of polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var points = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
        return points
    }

    /// At most 400 points, enough to draw the route and small enough to save.
    private static func thinned(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count > 400 else { return points }
        let stride = Double(points.count - 1) / 399
        return (0..<400).map { points[Int((Double($0) * stride).rounded())] }
    }

    private static func describe(_ category: MKPointOfInterestCategory?) -> (symbol: String, kind: String) {
        switch category {
        case .park?: return ("tree.fill", "A park")
        case .nationalPark?: return ("mountain.2.fill", "A national park")
        case .beach?: return ("beach.umbrella.fill", "A beach")
        case .museum?: return ("building.columns.fill", "A museum")
        case .marina?: return ("sailboat.fill", "A marina")
        case .zoo?: return ("pawprint.fill", "A zoo")
        case .stadium?: return ("sportscourt.fill", "A stadium")
        case .university?: return ("graduationcap.fill", "A university")
        case .library?: return ("books.vertical.fill", "A library")
        case .amusementPark?: return ("ferriswheel", "An amusement park")
        case .aquarium?: return ("fish.fill", "An aquarium")
        default: return ("mappin.circle.fill", "A landmark")
        }
    }
}
