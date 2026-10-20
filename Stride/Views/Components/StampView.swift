import StrideCore
import SwiftUI

/// A passport stamp for a day the goal was met. Ink color and tilt vary by date.
struct StampView: View {
    let day: Day
    let steps: Int
    var size: CGFloat = 96

    private var ink: Color {
        Color.stampInks[(day.year * 372 + day.month * 31 + day.day) % Color.stampInks.count]
    }

    private var tilt: Double {
        Double((day.day * 37 + day.month * 11) % 17) - 8
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(ink, lineWidth: size * 0.035)
            Circle()
                .strokeBorder(ink, style: StrokeStyle(lineWidth: size * 0.012, dash: [size * 0.025, size * 0.02]))
                .padding(size * 0.085)
            ArcText(text: "GOAL MET", radius: size * 0.33, fontSize: size * 0.08)
            VStack(spacing: 0) {
                Text(day.startDate().formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: size * 0.085, weight: .bold))
                Text("\(day.day)")
                    .font(.system(size: size * 0.27, weight: .black))
                    .fontWidth(.compressed)
                Text(steps.formatted())
                    .font(.system(size: size * 0.075, weight: .semibold))
                    .monospacedDigit()
            }
            .offset(y: size * 0.04)
        }
        .foregroundStyle(ink)
        .frame(width: size, height: size)
        .opacity(0.9)
        .rotationEffect(.degrees(tilt))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Goal met on \(StrideFormat.date(day)) with \(steps.formatted()) steps")
    }
}

/// Text set along the top of a circle.
struct ArcText: View {
    let text: String
    let radius: CGFloat
    let fontSize: CGFloat
    var degreesPerCharacter: Double = 12

    var body: some View {
        let characters = Array(text)
        let span = degreesPerCharacter * Double(characters.count - 1)
        ZStack {
            ForEach(characters.indices, id: \.self) { index in
                Text(String(characters[index]))
                    .font(.system(size: fontSize, weight: .heavy))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(-span / 2 + Double(index) * degreesPerCharacter))
            }
        }
    }
}

/// An empty dashed circle where the next stamp will go.
struct StampPlaceholder: View {
    var size: CGFloat = 96

    var body: some View {
        Circle()
            .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "seal")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.tertiary)
            }
    }
}
