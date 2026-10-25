import SwiftUI
import TenazCore

/// The prompt itself, as big as the card allows: the English word for recognition (the hero), the
/// Spanish cue for recall, the sentence with its gap for cloze and collocation.
struct OverlayPrompt: View {
    let prompt: CardPrompt
    var compact = false

    var body: some View {
        switch prompt.type {
        case .recognition:
            Text(prompt.text)
                .font(Typography.display(compact ? 44 : 200))
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .fixedSize(horizontal: false, vertical: true)
        case .recall:
            Text(prompt.text)
                .font(Typography.display(compact ? 32 : 112))
                .foregroundStyle(Tokens.ink)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.4)
                .fixedSize(horizontal: false, vertical: true)
        default:
            OverlayGapSentence(sentence: prompt.text, compact: compact)
        }
    }
}
