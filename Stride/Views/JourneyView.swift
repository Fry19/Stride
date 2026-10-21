import StrideCore
import SwiftUI

struct JourneyView: View {
    @Environment(AppModel.self) private var model
    @State private var openPostcard: ReachedStop?
    @State private var showingMap = false

    var body: some View {
        let journey = model.summary.journey
        let color = Color.route(journey.route.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "\(journey.reached.count) postcards collected", title: "Journey")
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
                .accessibilityLabel("Open the map of the \(journey.route.name)")
                RouteHero(journey: journey)

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "Stops")
                        .padding(.bottom, 14)
                    ForEach(Array(journey.route.stops.enumerated()), id: \.element.id) { index, stop in
                        StopRow(stop: stop, journey: journey, color: color,
                                isFirst: index == 0, isLast: index == journey.route.stops.count - 1) {
                            openPostcard = journey.reachedStop(stop)
                        }
                    }
                }
                .glass()

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "Routes")
                    ForEach(Journeys.routes) { route in
                        RouteRow(route: route, journey: journey)
                    }
                    Text("Routes are walked in order. Distances are approximate.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .glass()

                if !journey.reached.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Postcards")
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(journey.reached.reversed()) { reached in
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground(glow: color))
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
        .fullScreenCover(isPresented: $showingMap) {
            JourneyMapScreen(journey: journey)
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
                Text("≈ \(StrideFormat.distance(km: journey.kmIntoRoute)) of \(StrideFormat.distance(km: journey.route.lengthKm, decimals: 0))")
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
            return "You've walked every route, about \(StrideFormat.distance(km: journey.totalKm, decimals: 0)) in all."
        }
        if let stop = journey.nextStop, let km = journey.kmToNextStop {
            return "Next stop: \(stop.name), ≈ \(StrideFormat.distance(km: km)) away."
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

private struct RouteRow: View {
    let route: Route
    let journey: JourneyProgress

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.route(route.id))
                .frame(width: 6, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(route.region) · ≈ \(StrideFormat.distance(km: route.lengthKm, decimals: 0))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text(status.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.16), in: Capsule())
                .foregroundStyle(statusColor)
        }
    }

    private var isDone: Bool {
        journey.totalKm >= Journeys.startKm(of: route) + route.lengthKm
    }

    private var status: String {
        if isDone { return "Complete" }
        if route.id == journey.route.id { return "Walking" }
        return "Locked"
    }

    private var statusColor: Color {
        if isDone { return Theme.live }
        if route.id == journey.route.id { return Color.route(route.id) }
        return Theme.textTertiary
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
