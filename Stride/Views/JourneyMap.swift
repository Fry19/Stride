import MapKit
import StrideCore
import SwiftUI

extension Stop {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension Coordinate {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension JourneyProgress {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// The part of the route already walked, ending where you are.
    var walkedPath: [CLLocationCoordinate2D] {
        let path = route.path
        guard path.count > route.stops.count, path.count > 1 else {
            return route.stops.filter { reachedStop($0) != nil }.map(\.location) + [location]
        }
        let legs = zip(path, path.dropFirst()).map { $0.km(to: $1) }
        var remaining = legs.reduce(0, +) * routeFraction
        var walked = [path[0].location]
        for (index, leg) in legs.enumerated() {
            guard remaining > leg else { break }
            walked.append(path[index + 1].location)
            remaining -= leg
        }
        return walked + [location]
    }
}

/// The current route on satellite imagery: the full route dashed, the part walked solid,
/// and a marker where you are.
struct JourneyMap: View {
    let journey: JourneyProgress
    var interactive = false

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        let color = Color.route(journey.route.id)
        let stops = journey.route.stops
        let walked = journey.walkedPath
        Map(position: $position, interactionModes: interactive ? .all : []) {
            MapPolyline(coordinates: journey.route.path.map(\.location))
                .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 7]))
            MapPolyline(coordinates: walked)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            ForEach(stops) { stop in
                Annotation(stop.name, coordinate: stop.location) {
                    Circle()
                        .fill(journey.reachedStop(stop) != nil ? color : Color.white)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
                }
                .annotationTitles(interactive ? .automatic : .hidden)
            }
            Annotation("You", coordinate: journey.location) {
                YouMarker(color: color)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(journey.route.id.hasPrefix("nearby") ? .hybrid(elevation: .realistic) : .imagery(elevation: .realistic))
    }
}

/// A small, still map of a route, for choosing a journey.
struct RoutePreviewMap: View {
    let route: Route

    var body: some View {
        let color = Color.route(route.id)
        Map(initialPosition: .automatic, interactionModes: []) {
            MapPolyline(coordinates: route.path.map(\.location))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            if let first = route.stops.first {
                Annotation("Start", coordinate: first.location) {
                    Circle().fill(.white).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(color, lineWidth: 3))
                }
                .annotationTitles(.hidden)
            }
            if let last = route.stops.last {
                Annotation(last.name, coordinate: last.location) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(color, in: Circle())
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
    }
}

private struct YouMarker: View {
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 34, height: 34)
                .scaleEffect(pulsing ? 1.4 : 0.8)
                .opacity(pulsing ? 0 : 1)
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
        .accessibilityLabel("You are here")
    }
}

/// The full-screen map of the current route.
struct JourneyMapScreen: View {
    let journey: JourneyProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        JourneyMap(journey: journey, interactive: true)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(journey.route.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Positions are approximate")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Spacer()
                    GlassIconButton(systemImage: "xmark", label: "Close") {
                        dismiss()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
    }
}

/// A real view of a stop: Apple's Look Around street imagery where it exists,
/// otherwise a tilted 3D satellite view.
struct StopPlaceView: View {
    let stop: Stop

    @State private var scene: MKLookAroundScene?

    var body: some View {
        ZStack {
            if let scene {
                LookAroundPreview(initialScene: scene)
            } else {
                Map(initialPosition: .camera(MapCamera(centerCoordinate: stop.location, distance: 1_600,
                                                       heading: 30, pitch: 60))) {
                    Marker(stop.name, coordinate: stop.location)
                }
                .mapStyle(.imagery(elevation: .realistic))
            }
        }
        .task(id: stop.id) {
            scene = try? await MKLookAroundSceneRequest(coordinate: stop.location).scene
        }
    }
}
