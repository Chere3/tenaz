import SwiftUI

/// The folded top-right corner of a sticker: page colour behind, card-coloured flap in front.
struct PeelCorner: View {
    var body: some View {
        Canvas { context, size in
            var behind = Path()
            behind.move(to: .zero)
            behind.addLine(to: CGPoint(x: size.width, y: 0))
            behind.addLine(to: CGPoint(x: size.width, y: size.height))
            behind.closeSubpath()
            context.fill(behind, with: .color(Tokens.paper))
            var flap = Path()
            flap.move(to: .zero)
            flap.addLine(to: CGPoint(x: size.width, y: size.height))
            flap.addLine(to: CGPoint(x: 0, y: size.height))
            flap.closeSubpath()
            context.fill(flap, with: .color(Tokens.card))
            context.stroke(flap, with: .color(Tokens.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
