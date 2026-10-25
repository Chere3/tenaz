import SwiftUI
import TenazCore

/// The small line above the prompt that says what to do, in plain words (sentence case).
struct OverlayKicker: View {
    let type: CardType
    var compact = false

    var text: String {
        switch type {
        case .recognition: "What does it mean?"
        case .cloze: "Fill the gap"
        case .recall: "Say it in English"
        case .collocation: "Complete the phrase"
        case .production: "Write a sentence"
        case .spelling: "Spell it"
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 12 : 18, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.brand)
    }
}
