import MapKit
import StrideCore
import SwiftUI

extension Walk.Point {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum WalkFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// Minutes per mile or kilometer.
    static func pace(seconds: TimeInterval, meters: Double) -> String {
        let unit = StrideFormat.usesMiles ? 1_609.344 : 1_000
        guard meters > 50 else { return "–" }
        let perUnit = seconds / (meters / unit)
        return "\(Int(perUnit) / 60):\(String(format: "%02d", Int(perUnit) % 60)) /\(StrideFormat.usesMiles ? "mi" : "km")"
    }
}

/// The walk in progress, full screen: a map following you, with time, steps, distance and pace.
struct WalkView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var finished: Walk?
    @State private var confirmingEnd = false
    @AppStorage(WalkPreferences.spokenUpdatesKey) private var spokenUpdates = true

    var body: some View {
        let walk = model.walk
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                UserAnnotation()
                if walk.route.count > 1 {
                    MapPolyline(coordinates: walk.route)
                        .stroke(LinearGradient(colors: Theme.ringColors, startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
            .mapControls { MapUserLocationButton() }
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                GlassIconButton(systemImage: spokenUpdates ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                label: spokenUpdates ? "Mute spoken updates" : "Turn on spoken updates") {
                    spokenUpdates.toggle()
                }
                .padding(.leading, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 18) {
                if let start = walk.timerStart {
                    VStack(spacing: 2) {
                        Text(walk.isPaused ? (walk.isAutoPaused ? "AUTO-PAUSED" : "PAUSED") as String : "WALKING")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(walk.isPaused ? Color(hex: 0xFFC247) : Theme.textTertiary)
                        Text(timerInterval: start...Date.distantFuture, pauseTime: walk.pausedAt, countsDown: false)
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .opacity(walk.isPaused ? 0.55 : 1)
                    }
                }
                HStack(spacing: 12) {
                    WalkStat(value: walk.steps.formatted(), label: "Steps")
                    WalkStat(value: StrideFormat.distance(meters: walk.meters, decimals: 2), label: "Distance")
                    TimelineView(.periodic(from: .now, by: 5)) { context in
                        WalkStat(value: WalkFormat.pace(seconds: walk.movingSeconds(at: context.date), meters: walk.meters),
                                 label: "Pace")
                    }
                }
                if walk.locationDenied {
                    Text("Location is off, so there's no route map. Steps still count.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .accessibilityLabel("Hide, keep walking")
                    Button {
                        if walk.isPaused { model.resumeWalk() } else { model.pauseWalk() }
                    } label: {
                        Image(systemName: walk.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.1), in: Circle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(walk.isPaused ? "Resume" : "Pause")
                    .sensoryFeedback(.impact, trigger: walk.isPaused)
                    Button("End walk") {
                        confirmingEnd = true
                    }
                    .buttonStyle(GlowButtonStyle())
                }
            }
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.background.opacity(0.88))
                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Theme.hairline))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .confirmationDialog("End this walk?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End walk") {
                finished = model.finishWalk()
                if finished == nil { dismiss() }
            }
        } message: {
            Text("It will be saved with its route.")
        }
        .sheet(item: $finished, onDismiss: { dismiss() }) { walk in
            WalkDetailView(walk: walk, isSummary: true)
        }
    }
}

private struct WalkStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A walk's route and stats. Shown right after a walk ends, and from the walk list.
struct WalkDetailView: View {
    let walk: Walk
    var isSummary = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var savedToHealth: Bool {
        model.walks.first { $0.id == walk.id }?.savedToHealth ?? walk.savedToHealth ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isSummary {
                        Text("Walk complete")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    WalkRouteMap(walk: walk)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            WalkStat(value: walk.steps.formatted(), label: "Steps")
                            WalkStat(value: StrideFormat.distance(meters: walk.meters, decimals: 2), label: "Distance")
                        }
                        GridRow {
                            WalkStat(value: WalkFormat.duration(walk.duration), label: "Time")
                            WalkStat(value: WalkFormat.pace(seconds: walk.duration, meters: walk.meters), label: "Pace")
                        }
                    }
                    if let splits = walk.splits, !splits.isEmpty {
                        SplitsView(splits: splits, metersEach: walk.splitMeters ?? 1_000)
                    }
                    HStack(spacing: 6) {
                        Text(walk.start.formatted(date: .complete, time: .shortened))
                        if savedToHealth {
                            Text("·")
                            Label("Saved to Apple Health", systemImage: "heart.fill")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(isSummary ? "" : "Walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(Theme.background)
    }
}

/// Time for each whole mile or kilometer, the fastest highlighted.
private struct SplitsView: View {
    let splits: [TimeInterval]
    let metersEach: Double

    var body: some View {
        let slowest = splits.max() ?? 1
        let fastest = splits.min() ?? 0
        let unit = metersEach > 1_500 ? "Mile" : "Km"
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Splits")
            ForEach(Array(splits.enumerated()), id: \.offset) { index, split in
                HStack(spacing: 12) {
                    Text("\(unit) \(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 58, alignment: .leading)
                    GeometryReader { geometry in
                        Capsule()
                            .fill(split == fastest && splits.count > 1
                                  ? AnyShapeStyle(LinearGradient(colors: Theme.ringColors, startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.white.opacity(0.18)))
                            .frame(width: max(8, geometry.size.width * split / slowest))
                    }
                    .frame(height: 8)
                    Text(WalkFormat.duration(split))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 58, alignment: .trailing)
                }
            }
        }
        .glass(radius: 22, padding: 16)
    }
}

/// A finished walk's route.
struct WalkRouteMap: View {
    let walk: Walk
    var interactive = true

    var body: some View {
        let points = walk.route.map(\.location)
        Map(initialPosition: .automatic, interactionModes: interactive ? .all : []) {
            if points.count > 1 {
                MapPolyline(coordinates: points)
                    .stroke(LinearGradient(colors: Theme.ringColors, startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if let first = points.first {
                Annotation("Start", coordinate: first) {
                    Circle().fill(Theme.live).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
        .overlay {
            if points.count < 2 {
                Text("No route recorded")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

/// The start button, or the walk in progress, for the Today screen.
struct WalkLauncher: View {
    @Environment(AppModel.self) private var model
    let open: () -> Void

    var body: some View {
        let walk = model.walk
        if let start = walk.timerStart {
            Button(action: open) {
                HStack(spacing: 14) {
                    if walk.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFFC247))
                    } else {
                        LiveDot()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(walk.isPaused ? "Walk paused" as String : "Walk in progress")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("\(walk.steps.formatted()) steps · \(StrideFormat.distance(meters: walk.meters, decimals: 2))")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text(timerInterval: start...Date.distantFuture, pauseTime: walk.pausedAt, countsDown: false)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 80, alignment: .trailing)
                }
                .glass(radius: 22, padding: 16)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                model.startWalk()
                open()
            } label: {
                Label("Start a walk", systemImage: "figure.walk")
            }
            .buttonStyle(GlowButtonStyle())
        }
    }
}

/// The most recent walks, for the Today screen.
struct RecentWalks: View {
    let walks: [Walk]
    @State private var open: Walk?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Recent walks")
            ForEach(walks.prefix(3)) { walk in
                Button {
                    open = walk
                } label: {
                    HStack(spacing: 14) {
                        WalkRouteMap(walk: walk, interactive: false)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .allowsHitTesting(false)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(walk.start.formatted(.dateTime.weekday(.wide).hour().minute()))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(walk.steps.formatted()) steps · \(StrideFormat.distance(meters: walk.meters, decimals: 2)) · \(WalkFormat.duration(walk.duration))")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .glass()
        .sheet(item: $open) { walk in
            WalkDetailView(walk: walk)
        }
    }
}
