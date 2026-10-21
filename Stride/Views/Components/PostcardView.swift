import StrideCore
import SwiftUI

/// The collectible for reaching a stop on the journey.
struct PostcardView: View {
    let reached: ReachedStop

    private var color: Color { Color.route(reached.route.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(reached.route.name.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                Spacer()
                Text(reached.route.region)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(color)

            Text(reached.stop.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(reached.stop.fact)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label("Reached \(StrideFormat.date(reached.day))", systemImage: "mappin.and.ellipse")
                Spacer()
                Text(distanceText)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.textTertiary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.28), Color.white.opacity(0.04)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LinearGradient(colors: [color.opacity(0.6), Color.white.opacity(0.05)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
    }

    private var distanceText: String {
        reached.stop.km == 0 ? "Start" : "≈ \(StrideFormat.distance(km: reached.stop.km, decimals: 0)) in"
    }
}
