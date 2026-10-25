import SwiftUI

/// Large single-underline answer field. Validation shows only after Return: correct = green + check + word,
/// wrong = red + cross + the right answer, with a 4 pt shake (none under Reduce Motion). Never red while typing.
struct AnswerField: View {
    @Binding var text: String
    var prompt = "Type your answer"
    var feedback: AnswerFeedback = .none
    var allowsPaste = true
    var onSubmit: () -> Void = {}
    /// Esc while typing; nil keeps the text view's default.
    var onCancel: (() -> Void)?
    /// false = the screen draws its own correct/wrong panel; only "Return to check" shows here.
    var showsVerdict = true
    /// false hides the "Return to check" line when the screen's own primary already says it.
    var showsHint = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.s) {
                if isSnapshot {
                    SnapshotAnswerText(text: text, prompt: prompt)
                } else {
                    AnswerInput(text: $text, prompt: prompt, allowsPaste: allowsPaste, onSubmit: onSubmit, onCancel: onCancel)
                }
                AnswerGlyph(feedback: feedback)
            }
            Capsule()
                .fill(underline)
                .frame(height: 3)
            if feedback == .none ? showsHint : showsVerdict {
                AnswerVerdict(feedback: feedback)
            }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: feedback) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(shakeAmplitude, duration: 0.04)
                LinearKeyframe(-shakeAmplitude, duration: 0.04)
                LinearKeyframe(shakeAmplitude, duration: 0.04)
                LinearKeyframe(0, duration: 0.04)
            }
        }
    }

    private var shakeAmplitude: Double {
        guard case .wrong = feedback, !reduceMotion else { return 0 }
        return 4
    }

    private var underline: Color {
        switch feedback {
        case .none: Tokens.ink
        case .correct: Tokens.correct
        case .wrong: Tokens.wrong
        }
    }
}
