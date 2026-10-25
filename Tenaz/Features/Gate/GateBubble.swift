import SwiftUI

/// The question, as the one hero of the gate: big Fraunces on the indigo field, no bubble.
struct GateBubble: View {
    let question: String

    var body: some View {
        Text(question)
            // A long prompt (an advice situation, a story opener) steps down instead of being crushed.
            .font(Typography.display(question.count > 110 ? 40 : 52, weight: 800))
            .foregroundStyle(Tokens.ink)
            .lineSpacing(2)
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Tena asks: \(question)")
    }
}
