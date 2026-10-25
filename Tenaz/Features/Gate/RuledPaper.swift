import SwiftUI

/// Notebook ruling: faint ink lines, nothing else.
struct RuledPaper: View {
    var lineSpacing: CGFloat = 38
    var topInset: CGFloat = 40
    var margin: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            var lines = Path()
            var y = topInset
            while y < size.height - 6 {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += lineSpacing
            }
            context.stroke(lines, with: .color(Tokens.ink.opacity(0.10)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
