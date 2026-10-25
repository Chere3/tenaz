import SwiftUI

/// Tena's reaction beside the word, matched to the flood: curious while asking, ecstatic when right,
/// focused and encouraging when wrong.
struct OverlayTena: View {
    let phase: OverlayPhase
    let stage: TenaStage
    var size: CGFloat = 200

    private var mood: TenaMood {
        switch phase {
        case .asking: .curious
        case .correct: .ecstatic
        case .wrong: .happy
        case let .done(correct, total, _): correct == total ? .ecstatic : .proud
        }
    }

    private var line: String {
        switch phase {
        case .asking: "You know this one."
        case .correct: "Yes! That's it."
        case .wrong: "We go again soon."
        case let .done(correct, total, _): correct == total ? "Perfect. Back to work!" : "Good. Back to work!"
        }
    }

    var body: some View {
        TenaView(mood: mood, stage: stage, size: size)
            .overlay(alignment: .top) {
                TenaLine(text: line)
                    .offset(x: -size * 0.1, y: size * 0.13)
            }
    }
}

/// Tena's one line, attached to her head: ink bubble with the tail pointing down, toward her.
private struct TenaLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.paper)
            .fixedSize()
            .padding(.horizontal, Tokens.Space.s)
            .padding(.top, Tokens.Space.xs + 3)
            .padding(.bottom, Tokens.Space.xs + 3 + 9)
            .background { Tail().fill(Tokens.ink) }
            .accessibilityLabel("Tena says: \(text)")
    }

    private struct Tail: Shape {
        func path(in rect: CGRect) -> Path {
            let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 9)
            let path = Path(roundedRect: body, cornerRadius: 12, style: .continuous)
            let x = body.minX + body.width * 0.68
            var beak = Path()
            beak.move(to: CGPoint(x: x - 8, y: body.maxY - 1))
            beak.addLine(to: CGPoint(x: x + 3, y: rect.maxY))
            beak.addLine(to: CGPoint(x: x + 8, y: body.maxY - 1))
            beak.closeSubpath()
            return path.union(beak)
        }
    }
}
