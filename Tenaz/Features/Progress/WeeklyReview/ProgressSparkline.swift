import SwiftUI

/// A 30-day line in ink with the last point marked. Flat: no fill, no outline.
struct ProgressSparkline: View {
    let values: [Int]

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let maxV = max(1, values.max() ?? 1)
            let minV = min(values.min() ?? 0, maxV - 1)
            let inset: CGFloat = 6
            func point(_ i: Int) -> CGPoint {
                let x = inset + (size.width - inset * 2) * CGFloat(i) / CGFloat(values.count - 1)
                let y = size.height - inset - (size.height - inset * 2) * CGFloat(values[i] - minV) / CGFloat(maxV - minV)
                return CGPoint(x: x, y: y)
            }
            var line = Path()
            line.move(to: point(0))
            for i in 1..<values.count { line.addLine(to: point(i)) }
            var base = Path()
            base.move(to: CGPoint(x: 0, y: size.height - 0.5))
            base.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
            context.stroke(base, with: .color(Tokens.ink.opacity(0.12)), lineWidth: 1)
            context.stroke(line, with: .color(Tokens.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            let last = point(values.count - 1)
            context.fill(Path(ellipseIn: CGRect(x: last.x - 6, y: last.y - 6, width: 12, height: 12)), with: .color(Tokens.ink))
        }
        .accessibilityElement()
        .accessibilityLabel("Mastered words over 30 days")
        .accessibilityValue("from \(values.first ?? 0) to \(values.last ?? 0)")
    }
}
