import SwiftUI

/// The question itself, set straight on the flood (no card): what to recall, by card type. A Spanish
/// gloss on gap cards hides behind a small "?" so the sentence does the work first.
struct ReviewPromptView: View {
    let card: ReviewCardModel
    @State private var showsGloss = false

    /// Gap cards carry the Spanish gloss as their hint: that one is hidden until asked for.
    private var hidesHint: Bool { card.type == .cloze || card.type == .collocation }

    /// The plain-words instruction, only where the prompt alone does not say what to do.
    private var instruction: String? {
        switch card.type {
        case .cloze: nil
        default: card.instruction
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            if let instruction {
                Text(instruction)
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.brand)
            }
            switch card.type {
            case .recognition:
                Text(card.text)
                    .font(Typography.display(card.text.count > 14 ? 72 : 104))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            case .cloze, .collocation:
                GapSentence(sentence: card.text, size: card.text.count > 90 ? 40 : 50)
            case .recall:
                Text(card.text)
                    .font(Typography.prompt)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            case .production, .spelling:
                Text(card.text)
                    .font(Typography.display(card.text.count > 40 ? 36 : 44, weight: 800))
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let hint = card.hint, !hint.isEmpty {
                if hidesHint {
                    if showsGloss {
                        Text(hint)
                            .font(Typography.body)
                            .foregroundStyle(Tokens.brand)
                            .transition(.opacity)
                    }
                } else {
                    Text(hint)
                        .font(Typography.body)
                        .italic(card.type == .recognition)
                        .foregroundStyle(Tokens.brand)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            if hidesHint, card.hint?.isEmpty == false {
                glossToggle
            }
        }
    }

    /// The small "?" at the right edge, level with the end of the sentence.
    private var glossToggle: some View {
        Button {
            showsGloss.toggle()
        } label: {
            Text("?")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Tokens.ink.opacity(showsGloss ? 0.16 : 0.08)))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Show the Spanish hint")
        .accessibilityLabel(showsGloss ? "Hide the Spanish hint" : "Show the Spanish hint")
    }
}
