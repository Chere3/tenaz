import SwiftUI

/// The line under the answer: the word, never a verdict ("Correct", or the right answer to copy).
struct AnswerVerdict: View {
    let feedback: AnswerFeedback

    var body: some View {
        switch feedback {
        case .none:
            Text("Return to check")
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
        case .correct:
            Label("Correct", systemImage: "checkmark")
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.correct)
        case let .wrong(expected):
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Label("Answer", systemImage: "xmark")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.wrong)
                Text(expected)
                    .font(Typography.displayS)
                    .foregroundStyle(Tokens.ink)
                Text("again in 10 min")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
        }
    }
}
