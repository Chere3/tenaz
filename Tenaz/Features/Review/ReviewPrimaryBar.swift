import SwiftUI

/// Under an open question: the way out of a stuck card on the left, the one primary action on the right.
struct ReviewPrimaryBar: View {
    let card: ReviewCardModel
    let typedEmpty: Bool
    let actions: ReviewActions

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Button(action: actions.reveal) {
                HStack(spacing: 6) {
                    Text("I don't know")
                    KeyCap("⌘D")
                }
            }
            .buttonStyle(.ink)
            .padding(.leading, -Tokens.Space.s)
            .keyboardShortcut("d", modifiers: .command)
            Spacer()
            if card.isChoice {
                Text("Press 1, 2, 3 or 4")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            } else {
                Button(action: actions.submit) {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Check")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .disabled(typedEmpty)
                .frame(width: 200)
            }
        }
    }
}
