import SwiftUI

/// Four options on one paper sheet (2×2, split by hairlines); keys 1-4 pick while the question is open.
struct ChoiceGrid: View {
    let card: ReviewCardModel
    let choose: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 2, id: \.self) { row in
                if row > 0 { Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: Tokens.rule) }
                HStack(spacing: 0) {
                    ForEach(0 ..< 2, id: \.self) { column in
                        let index = row * 2 + column
                        if column > 0 { Rectangle().fill(Tokens.ink.opacity(0.12)).frame(width: Tokens.rule) }
                        if card.options.indices.contains(index) {
                            ChoiceOption(number: index + 1, text: card.options[index]) {
                                choose(index)
                            }
                            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper))
        .clipShape(.rect(cornerRadius: Tokens.Radius.sheet, style: .continuous))
    }
}

/// One Spanish option: its number key and the text. Hover lays ink at 6 % behind it.
private struct ChoiceOption: View {
    let number: Int
    let text: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.m) {
                KeyCap("\(number)")
                    .foregroundStyle(Tokens.ink)
                Text(text)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.m)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Tokens.ink.opacity(hovering ? 0.06 : 0))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Option \(number): \(text)")
    }
}
