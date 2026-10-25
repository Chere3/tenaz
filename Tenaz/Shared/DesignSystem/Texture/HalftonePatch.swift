import SwiftUI

/// A rectangle of halftone dots that fade along a direction (unit points, like gradients).
struct HalftonePatch: View {
    var color: Color = Tokens.ink
    var spacing: CGFloat = 6
    var start: UnitPoint = .leading
    var end: UnitPoint = .trailing
    var low: CGFloat = 0
    var high: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let from = CGPoint(x: start.x * size.width, y: start.y * size.height)
            let to = CGPoint(x: end.x * size.width, y: end.y * size.height)
            let dots = Halftone.dots(in: rect, spacing: spacing, coverage: Halftone.ramp(from: from, to: to, low: low, high: high))
            context.fill(dots, with: .color(color))
        }
        .accessibilityHidden(true)
    }
}
