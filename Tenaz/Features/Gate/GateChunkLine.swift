import SwiftUI
import TenazCore

/// "2-3 sentences, 25-40 words. Use: follow up on" with the chunk underlined in Fraunces.
struct GateChunkLine: View {
    let prompt: GatePrompt
    let minWords: Int
    let target: Int

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            Text("2–3 sentences, \(minWords)–\(target) words. Use")
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
            Text(prompt.chunk)
                .font(Typography.display(26))
                .underline(true, color: Tokens.ink)
                .foregroundStyle(Tokens.ink)
            if prompt.chunkIsForgottenWord {
                Label("You missed it twice today", systemImage: "arrow.uturn.backward")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.brand)
                    .padding(.leading, Tokens.Space.xs)
            }
        }
    }
}
