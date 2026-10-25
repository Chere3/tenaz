import SwiftUI

/// The check or cross at the end of the answer line.
struct AnswerGlyph: View {
    let feedback: AnswerFeedback

    var body: some View {
        switch feedback {
        case .none:
            EmptyView()
        case .correct:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Tokens.correct)
                .accessibilityLabel("Correct")
        case .wrong:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Tokens.wrong)
                .accessibilityLabel("Wrong")
        }
    }
}
