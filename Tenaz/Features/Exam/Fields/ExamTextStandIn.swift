import SwiftUI

/// What `ExamTextField` looks like in an off-screen snapshot: the text (or prompt) and the caret.
struct ExamTextStandIn: View {
    let text: String
    let prompt: String
    let multiline: Bool
    let fontSize: CGFloat
    var weight: Font.Weight = .medium
    let isFocused: Bool

    var body: some View {
        let shown = text.isEmpty ? prompt : text
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(shown)
                .font(.system(size: fontSize, weight: weight, design: .rounded))
                .foregroundStyle(text.isEmpty ? Tokens.brand.opacity(0.45) : Tokens.ink)
                .lineSpacing(multiline ? 4 : 0)
                .fixedSize(horizontal: false, vertical: multiline)
            if isFocused && !text.isEmpty {
                Capsule().fill(Tokens.ink).frame(width: 3, height: fontSize * 1.1)
            }
        }
        .padding(.top, multiline ? 6 : 0)
        .frame(maxWidth: .infinity, maxHeight: multiline ? .infinity : nil, alignment: .topLeading)
    }
}
