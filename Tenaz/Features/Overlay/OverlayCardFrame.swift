import SwiftUI

extension OverlayPhase {
    /// The flood is the state: yellow while it is your turn, mint when right, coral when wrong.
    var flood: Flood {
        switch self {
        case .asking: .turn
        case .correct, .done: .good
        case .wrong: .fix
        }
    }
}

/// The poster/sticker field: one flat flood, rounded by the panel. No outline, no shadow. The colour
/// crossfades with the answer (a glyph and a word always say the same thing elsewhere).
struct OverlayCardFrame: ViewModifier {
    let phase: OverlayPhase
    var radius: CGFloat = Tokens.Radius.card

    func body(content: Content) -> some View {
        content
            .flood(phase.flood)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func overlayCard(_ phase: OverlayPhase, radius: CGFloat = Tokens.Radius.card) -> some View {
        modifier(OverlayCardFrame(phase: phase, radius: radius))
    }
}

/// Sunburst rays (ink 7 %), only on right answers and the end of a batch.
struct OverlayRays: View {
    var center: UnitPoint = .bottomTrailing

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width * center.x, y: size.height * center.y)
            let reach = hypot(size.width, size.height) * 1.2
            let count = 14
            for i in 0 ..< count where i.isMultiple(of: 2) {
                let a0 = Double(i) / Double(count) * 2 * .pi
                let a1 = Double(i + 1) / Double(count) * 2 * .pi
                var wedge = Path()
                wedge.move(to: c)
                wedge.addLine(to: CGPoint(x: c.x + reach * cos(a0), y: c.y + reach * sin(a0)))
                wedge.addLine(to: CGPoint(x: c.x + reach * cos(a1), y: c.y + reach * sin(a1)))
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Tokens.ink.opacity(0.07)))
            }
        }
        .accessibilityHidden(true)
    }
}
