import SwiftUI

struct Sparkline: View {
    let values: [Double]
    var maximum: Double = 100

    var body: some View {
        GeometryReader { geometry in
            let samples = Array(values.suffix(120))
            let upper = max(maximum, samples.max() ?? 1, 1)
            let points = samples.enumerated().map { index, value in
                let x = geometry.size.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1))
                let clamped = min(max(value, 0), upper)
                let y = geometry.size.height * (1 - CGFloat(clamped / upper))
                return CGPoint(x: x, y: y)
            }

            ZStack {
                Path { path in
                    let midY = geometry.size.height * 0.5
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
                }
                .stroke(
                    Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                )

                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geometry.size.height))
                        for point in points {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.30), .accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.accentColor, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    Text("Collecting…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
