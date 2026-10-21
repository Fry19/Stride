import StrideCore
import SwiftUI

struct JourneyView: View {
    @Environment(AppModel.self) private var model
    @State private var openPostcard: ReachedStop?
    @State private var showingMap = false
    @State private var showingPicker = ScreenshotMode.screen == "picker"

    var body: some View {
        let summary = model.summary
        let finished = summary.journeys.filter(\.isComplete).reversed()
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "\(summary.postcards.count) postcards collected", title: "Journey") {
                    if summary.journey != nil {
                        Button("Change") {
                            showingPicker = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    }
                }

                if let journey = summary.journey {
                    if journey.isComplete {
                        FinishedBanner(journey: journey) {
                            showingPicker = true
                        }
                    }
                    Button {
                        showingMap = true
                    } label: {
                        JourneyMap(journey: journey)
                            .frame(height: 230)
                            .allowsHitTesting(false)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Label("Explore", systemImage: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(12)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open the map of \(journey.route.name)")
                    RouteHero(journey: journey)

                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(text: "Stops")
                            .padding(.bottom, 14)
                        ForEach(Array(journey.route.stops.enumerated()), id: \.element.id) { index, stop in
                            StopRow(stop: stop, journey: journey, color: Color.route(journey.route.id),
                                    isFirst: index == 0, isLast: index == journey.route.stops.count - 1) {
                                openPostcard = journey.reachedStop(stop)
                            }
                        }
                    }
                    .glass()
                } else {
                    JourneyPicker()
                }

                if !summary.postcards.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Postcards")
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(summary.postcards.reversed()) { reached in
                                    Button {
                                        openPostcard = reached
                                    } label: {
                                        PostcardThumb(reached: reached)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                if !finished.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(text: "Finished journeys")
                        ForEach(Array(finished)) { journey in
                            HStack(spacing: 14) {
                                Image(systemName: "flag.checkered")
                                    .foregroundStyle(Color.route(journey.route.id))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(journey.route.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(StrideFormat.distance(km: journey.route.lengthKm)) · finished \(journey.completedOn.map(StrideFormat.date) ?? "")")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                Text("+\(StrideFormat.xp(journey.xp))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.xpColors[0])
                            }
                        }
                    }
                    .glass()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground(glow: summary.journey.map { Color.route($0.route.id) } ?? Theme.ember))
        .sheet(item: $openPostcard) { reached in
            ScrollView {
                VStack(spacing: 16) {
                    StopPlaceView(stop: reached.stop)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    PostcardView(reached: reached)
                }
                .padding(20)
            }
            .presentationDetents([.large])
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                ScrollView {
                    JourneyPicker {
                        showingPicker = false
                    }
                    .padding(20)
                }
                .background(Theme.background)
                .navigationTitle("Choose a journey")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingPicker = false }
                    }
                }
            }
            .presentationBackground(Theme.background)
        }
        .fullScreenCover(isPresented: $showingMap) {
            if let journey = summary.journey {
                JourneyMapScreen(journey: journey)
            }
        }
    }
}

private struct FinishedBanner: View {
    let journey: JourneyProgress
    let chooseNext: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.title2)
                .foregroundStyle(Color.route(journey.route.id))
            VStack(alignment: .leading, spacing: 2) {
                Text("You made it!")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(journey.route.name) is done. Where next?")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Choose", action: chooseNext)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.ember)
        }
        .glass(radius: 22, padding: 16)
    }
}

/// Nearby journeys found around the user, then the epic trails.
struct JourneyPicker: View {
    @Environment(AppModel.self) private var model
    var onStart: (() -> Void)?
    @State private var confirming: Route?

    var body: some View {
        let finder = model.nearby
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where will your steps take you?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Every step you take, on a walk or not, moves you along. Finish for bonus XP: 100 per kilometer.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(text: "Near you")
                    Spacer()
                    if finder.status == .ready {
                        Button {
                            Task { await finder.find() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                        .tint(Theme.textSecondary)
                    }
                }
                nearbyContent(finder)
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Epic trails")
                VStack(spacing: 0) {
                    ForEach(Journeys.epic) { route in
                        EpicRow(route: route, estimate: estimate(for: route), isCurrent: isCurrent(route)) {
                            choose(route)
                        }
                        if route.id != Journeys.epic.last?.id {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .glass(padding: 14)
                Text("Distances and positions on the famous trails are approximate.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .task {
            if finder.status == .idle && finder.hasPermission {
                await finder.find()
            }
        }
        .confirmationDialog("Switch journeys?", isPresented: isConfirming, titleVisibility: .visible,
                            presenting: confirming) { route in
            Button("Start \(route.name)") {
                model.startJourney(route)
                onStart?()
            }
        } message: { _ in
            Text("Your current journey ends here. Postcards you've collected stay.")
        }
    }

    @ViewBuilder
    private func nearbyContent(_ finder: NearbyJourneyFinder) -> some View {
        switch finder.status {
        case .idle:
            Button {
                Task { await finder.find() }
            } label: {
                Label("Find journeys near me", systemImage: "location.fill")
            }
            .buttonStyle(GlowButtonStyle())
            Text("Uses your location once to find parks, landmarks and other places worth walking to.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        case .locating, .searching:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text(finder.status == .locating ? "Finding where you are…" : "Planning walking routes…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .glass()
        case .needsPermission:
            VStack(alignment: .leading, spacing: 10) {
                Text("Stride needs your location to find journeys near you.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .glass()
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button("Try again") {
                    Task { await finder.find() }
                }
                .font(.subheadline.weight(.semibold))
            }
            .glass()
        case .ready:
            ForEach(finder.suggestions) { suggestion in
                NearbyCard(suggestion: suggestion, estimate: estimate(for: suggestion.route),
                           isCurrent: isCurrent(suggestion.route)) {
                    choose(suggestion.route)
                }
            }
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
    }

    private func isCurrent(_ route: Route) -> Bool {
        model.summary.journey?.route.id == route.id
    }

    private func choose(_ route: Route) {
        if let current = model.summary.journey, !current.isComplete {
            confirming = route
        } else {
            model.startJourney(route)
            onStart?()
        }
    }

    private func estimate(for route: Route) -> String {
        let days = Int((route.lengthKm / model.averageDailyKm).rounded(.up))
        switch days {
        case ...1: return "About a day of walking"
        case 2...60: return "About \(days) days at your pace"
        default: return "About \(Int((Double(days) / 30).rounded())) months at your pace"
        }
    }
}

private struct NearbyCard: View {
    let suggestion: NearbySuggestion
    let estimate: String
    let isCurrent: Bool
    let start: () -> Void

    var body: some View {
        let color = Color.route(suggestion.route.id)
        VStack(alignment: .leading, spacing: 12) {
            RoutePreviewMap(route: suggestion.route)
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: suggestion.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.route.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(StrideFormat.distance(km: suggestion.route.lengthKm)) on foot · \(estimate)")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                StartButton(isCurrent: isCurrent, action: start)
            }
        }
        .glass(radius: 24, padding: 14)
    }
}

private struct EpicRow: View {
    let route: Route
    let estimate: String
    let isCurrent: Bool
    let start: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.route(route.id))
                .frame(width: 6, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(route.region) · ≈ \(StrideFormat.distance(km: route.lengthKm, decimals: 0))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                Text(estimate)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            StartButton(isCurrent: isCurrent, action: start)
        }
        .padding(.vertical, 10)
    }
}

private struct StartButton: View {
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        if isCurrent {
            Text("WALKING")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.live)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.live.opacity(0.14), in: Capsule())
        } else {
            Button("Start", action: action)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.ember)
        }
    }
}

private struct RouteHero: View {
    let journey: JourneyProgress

    private var color: Color { Color.route(journey.route.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(journey.route.region.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(color)
            Text(journey.route.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, geometry.size.width * journey.routeFraction))
                        .shadow(color: color.opacity(0.6), radius: 8)
                }
            }
            .frame(height: 10)
            HStack(alignment: .firstTextBaseline) {
                Text("\(StrideFormat.distance(km: journey.kmIntoRoute)) of \(StrideFormat.distance(km: journey.route.lengthKm))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int((journey.routeFraction * 100).rounded(.down)))%")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            .monospacedDigit()
            Text(nextLine)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .glass(radius: 28, padding: 20)
    }

    private var nextLine: String {
        if journey.isComplete {
            return "Finished \(journey.completedOn.map(StrideFormat.date) ?? "") for +\(StrideFormat.xp(journey.xp))."
        }
        if let stop = journey.nextStop, let km = journey.kmToNextStop {
            return "Next: \(stop.name), \(StrideFormat.distance(km: km)) away. Finishing earns +\(StrideFormat.xp(journey.xp))."
        }
        return ""
    }
}

/// One stop on a vertical timeline.
private struct StopRow: View {
    let stop: Stop
    let journey: JourneyProgress
    let color: Color
    let isFirst: Bool
    let isLast: Bool
    let openPostcard: () -> Void

    private var reached: ReachedStop? { journey.reachedStop(stop) }
    private var isNext: Bool { journey.nextStop?.id == stop.id }

    var body: some View {
        Button(action: openPostcard) {
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : (reached != nil || isNext ? color : Theme.hairline))
                        .frame(width: 2)
                    marker
                    Rectangle()
                        .fill(isLast ? Color.clear : (reached != nil && !isNext ? color : Theme.hairline))
                        .frame(width: 2)
                }
                .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name)
                        .font(.body.weight(reached != nil || isNext ? .semibold : .regular))
                        .foregroundStyle(reached != nil || isNext ? Color.white : Theme.textTertiary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(isNext ? color : Theme.textTertiary)
                }
                .padding(.vertical, 10)
                Spacer()
                if reached != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(reached == nil)
    }

    @ViewBuilder private var marker: some View {
        if reached != nil {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(color: color.opacity(0.8), radius: 6)
        } else if isNext {
            Circle()
                .strokeBorder(color, lineWidth: 2.5)
                .frame(width: 16, height: 16)
        } else {
            Circle()
                .strokeBorder(Theme.textTertiary, lineWidth: 1.5)
                .frame(width: 10, height: 10)
        }
    }

    private var detail: String {
        if let reached {
            return "Reached \(StrideFormat.date(reached.day)) · postcard"
        }
        if isNext, let km = journey.kmToNextStop {
            return "≈ \(StrideFormat.distance(km: km)) to go"
        }
        return "≈ \(StrideFormat.distance(km: stop.km, decimals: 0)) from the start"
    }
}

private struct PostcardThumb: View {
    let reached: ReachedStop

    var body: some View {
        let color = Color.route(reached.route.id)
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(color)
            Spacer(minLength: 0)
            Text(reached.stop.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(StrideFormat.date(reached.day))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .frame(width: 140, height: 120, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.3), Color.white.opacity(0.04)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(0.35), lineWidth: 1)
        }
    }
}
