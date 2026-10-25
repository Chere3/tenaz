import SwiftUI

/// An open card, straight on the `.turn` flood: the prompt, the paper answer sheet (or the four
/// options), and the bar with "I don't know" and Check.
struct ReviewQuestion: View {
    let card: ReviewCardModel
    @Binding var typed: String
    let actions: ReviewActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: Tokens.Space.l)
            ReviewPromptView(card: card)
            Spacer(minLength: Tokens.Space.l)
                .frame(maxHeight: Tokens.Space.xxl)
            if card.isChoice {
                ChoiceGrid(card: card, choose: actions.choose)
            } else {
                ReviewAnswerSheet(text: $typed, prompt: card.type == .production ? "Type your sentence" : "Type the English",
                                  fontSize: card.type == .production ? 30 : 44,
                                  onSubmit: actions.submit, onCancel: actions.stop)
            }
            Spacer(minLength: Tokens.Space.l)
            ReviewPrimaryBar(card: card, typedEmpty: typed.isEmpty, actions: actions)
        }
    }
}
