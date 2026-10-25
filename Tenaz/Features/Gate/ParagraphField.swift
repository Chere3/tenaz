import SwiftUI

/// The gate's writing area: a paper sheet (always cream, with dark ink, on the indigo field) with
/// faint ruling and the paste-proof field. Snapshots draw the same text with SwiftUI
/// (ImageRenderer cannot draw AppKit views).
struct ParagraphField: View {
    @Binding var text: String
    var placeholder = "Start typing in English…"
    var onSubmit: () -> Void = {}
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        Group {
            if isSnapshot {
                Text(text.isEmpty ? placeholder : text)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .lineSpacing(9)
                    .foregroundStyle(text.isEmpty ? Tokens.brand.opacity(0.45) : Tokens.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 6)
            } else {
                ParagraphInput(text: $text, placeholder: placeholder, onSubmit: onSubmit)
            }
        }
        .padding(.horizontal, Tokens.Space.xl)
        .padding(.vertical, Tokens.Space.m)
        .frame(minHeight: 210, maxHeight: 250)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper)
                RuledPaper(lineSpacing: 38.5, topInset: Tokens.Space.m + 36)
                    .clipShape(.rect(cornerRadius: Tokens.Radius.sheet, style: .continuous))
            }
        }
        .environment(\.colorScheme, .light)
    }
}
