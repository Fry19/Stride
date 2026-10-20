import StrideCore
import SwiftUI

/// The collectible for reaching a stop on the journey.
struct PostcardView: View {
    let reached: ReachedStop

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(reached.route.name.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                Spacer()
                Text(reached.route.region)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.route(reached.route.id))

            VStack(alignment: .leading, spacing: 12) {
                Text(reached.stop.name)
                    .font(.system(size: 34, weight: .black))
                    .fontWidth(.condensed)
                Text(reached.stop.fact)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Label("Reached \(StrideFormat.date(reached.day))", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text(distanceText)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.route(reached.route.id).opacity(0.4), lineWidth: 1)
        }
    }

    private var distanceText: String {
        reached.stop.km == 0 ? "Start" : "≈ \(StrideFormat.distance(km: reached.stop.km, decimals: 0)) in"
    }
}
