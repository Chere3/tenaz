import SwiftUI

/// Tena's speech: one line in an ink bubble with paper text and a tail pointing left, towards her.
struct SpeechBubble: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.paper)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Tokens.Space.s + 9) // clear the 9 pt tail drawn inside the shape
            .padding(.trailing, Tokens.Space.s)
            .padding(.vertical, Tokens.Space.xs + 1)
            .padding(.vertical, 2)
            .background { BubbleShape().fill(Tokens.ink) }
            .accessibilityLabel("Tena says: \(text)")
    }
}

/// Rounded rectangle with a small tail on the left edge, a third of the way down.
private struct BubbleShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let tail: CGFloat = 9
        let body = CGRect(x: r.minX + tail, y: r.minY, width: r.width - tail, height: r.height)
        var path = Path(roundedRect: body, cornerRadius: 12, style: .continuous)
        let y = body.minY + min(22, body.height * 0.45)
        var beak = Path()
        beak.move(to: CGPoint(x: body.minX + 1, y: y - 7))
        beak.addLine(to: CGPoint(x: r.minX, y: y + 2))
        beak.addLine(to: CGPoint(x: body.minX + 1, y: y + 5))
        beak.closeSubpath()
        path = path.union(beak)
        return path
    }

    func inset(by amount: CGFloat) -> BubbleShape {
        BubbleShape(inset: inset + amount)
    }
}
