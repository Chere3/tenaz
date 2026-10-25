import SwiftUI

/// What `AnswerInput` looks like, drawn in SwiftUI for off-screen snapshots (text, or the prompt, then the caret).
struct SnapshotAnswerText: View {
    let text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 1) {
            Text(text.isEmpty ? prompt : text)
                .font(Typography.answer)
                .foregroundStyle(text.isEmpty ? Tokens.brand.opacity(0.45) : Tokens.ink)
            if !text.isEmpty {
                Capsule().fill(Tokens.accent).frame(width: 3, height: 30)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
