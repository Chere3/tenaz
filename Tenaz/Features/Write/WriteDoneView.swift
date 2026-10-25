import SwiftUI

/// After saving, on `.good`: the title is the hero, Tena's line, the XP, and Close. Tena herself hangs
/// off the bottom-right corner (drawn by `WriteBoard`).
struct WriteDoneView: View {
    /// Where the text column ends in the board (40 pt padding + the 400 pt column); Tena stays clear of it.
    static let textEdge: CGFloat = 440

    let result: WriteResult
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            if result.dayQualified {
                Sparkle(size: 20)
                    .padding(.bottom, Tokens.Space.s)
            }
            Text(result.dayQualified ? "Your day counts!" : "Saved!")
                .font(Typography.display(64))
                .foregroundStyle(Tokens.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(result.dayQualified ? "Words and a sentence. Streak safe, and I'm full!" : "\(result.words) words in English. Nice. Now some words?")
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Tokens.Space.s)
            if result.xp > 0 {
                Text("+\(result.xp) xp")
                    .font(Typography.numeric(18))
                    .foregroundStyle(Tokens.ink)
                    .padding(.top, Tokens.Space.xs)
            }
            Text("Claude checks it in the background; your mistakes show up in the Sunday review.")
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Tokens.Space.l)
            Button(action: close) {
                HStack(spacing: Tokens.Space.s) {
                    Text("Close")
                    KeyCap("Return")
                }
            }
            .buttonStyle(.fat)
            .keyboardShortcut(.defaultAction)
            .frame(width: 200)
            .padding(.top, Tokens.Space.xl)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 400, maxHeight: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
