import SwiftUI

/// Tena's pond: a wavy waterline, then halftone water that darkens towards the bottom.
struct PondWater: View {
    var body: some View {
        Canvas { context, size in
            let waterline = size.height * 0.42
            var water = Path()
            water.move(to: CGPoint(x: 0, y: waterline))
            let waves = 4
            let step = size.width / CGFloat(waves)
            for i in 0 ..< waves {
                let x = CGFloat(i) * step
                water.addQuadCurve(to: CGPoint(x: x + step, y: waterline), control: CGPoint(x: x + step / 2, y: waterline + (i.isMultiple(of: 2) ? -5 : 5)))
            }
            water.addLine(to: CGPoint(x: size.width, y: size.height))
            water.addLine(to: CGPoint(x: 0, y: size.height))
            water.closeSubpath()
            var layer = context
            layer.clip(to: water)
            let dots = Halftone.dots(in: CGRect(origin: .zero, size: size), spacing: 5, coverage: Halftone.ramp(
                from: CGPoint(x: 0, y: waterline), to: CGPoint(x: 0, y: size.height), low: 0.25, high: 0.85
            ))
            layer.fill(dots, with: .color(Tokens.brand.opacity(0.35)))
            context.stroke(water, with: .color(Tokens.brand.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}
