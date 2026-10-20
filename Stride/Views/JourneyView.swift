import StrideCore
import SwiftUI

struct JourneyView: View {
    @Environment(AppModel.self) private var model
    @State private var openPostcard: ReachedStop?

    var body: some View {
        let journey = model.summary.journey
        NavigationStack {
            List {
                Section {
                    RouteHeader(journey: journey)
                }

                Section("Stops") {
                    ForEach(journey.route.stops) { stop in
                        StopRow(stop: stop, journey: journey) {
                            openPostcard = journey.reachedStop(stop)
                        }
                    }
                }

                Section {
                    ForEach(Journeys.routes) { route in
                        RouteRow(route: route, journey: journey)
                    }
                } header: {
                    Text("Routes")
                } footer: {
                    Text("Routes are walked in order. Distances are approximate.")
                }

                if !journey.reached.isEmpty {
                    Section("Postcards · \(journey.reached.count)") {
                        ForEach(journey.reached.reversed()) { reached in
                            Button {
                                openPostcard = reached
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.route(reached.route.id))
                                        .frame(width: 10, height: 10)
                                    Text(reached.stop.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(StrideFormat.date(reached.day))
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Journey")
            .sheet(item: $openPostcard) { reached in
                PostcardView(reached: reached)
                    .padding()
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct RouteHeader: View {
    let journey: JourneyProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(journey.route.region.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.route(journey.route.id))
            Text(journey.route.name)
                .font(.system(size: 40, weight: .black))
                .fontWidth(.condensed)
            ProgressView(value: journey.routeFraction)
                .tint(Color.route(journey.route.id))
            HStack {
                Text("≈ \(StrideFormat.distance(km: journey.kmIntoRoute)) of \(StrideFormat.distance(km: journey.route.lengthKm, decimals: 0))")
                Spacer()
                Text("\(Int((journey.routeFraction * 100).rounded(.down)))%")
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            Text(nextLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
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

private struct StopRow: View {
    let stop: Stop
    let journey: JourneyProgress
    let openPostcard: () -> Void

    private var reached: ReachedStop? { journey.reachedStop(stop) }
    private var isNext: Bool { journey.nextStop?.id == stop.id }

    var body: some View {
        Button(action: openPostcard) {
            HStack(spacing: 14) {
                Image(systemName: reached != nil ? "mappin.circle.fill" : isNext ? "location.circle" : "circle.dashed")
                    .font(.title2)
                    .foregroundStyle(reached != nil ? Color.route(journey.route.id) : isNext ? Color.blaze : Color.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .font(.body.weight(reached != nil || isNext ? .semibold : .regular))
                        .foregroundStyle(reached != nil || isNext ? Color.primary : Color.secondary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if reached != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .disabled(reached == nil)
    }

    private var detail: String {
        if let reached {
            return "Reached \(StrideFormat.date(reached.day)) · tap for postcard"
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
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.route(route.id))
                .frame(width: 8, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.body.weight(.semibold))
                Text("\(route.region) · ≈ \(StrideFormat.distance(km: route.lengthKm, decimals: 0))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15), in: Capsule())
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
        if isDone { return Color.pine }
        if route.id == journey.route.id { return Color.blaze }
        return Color.secondary
    }
}
