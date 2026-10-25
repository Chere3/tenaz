import SwiftUI

/// The six floods: the colour is the state. Each shows its ink, name and what it means.
struct GalleryFloods: View {
    private static let meanings: [(Flood, String)] = [
        (.turn, "your turn: words due"),
        (.good, "right; all done today"),
        (.fix, "wrong: the fix, warm"),
        (.serious, "exams, writing gate"),
        (.risk, "streak about to break"),
        (.celebrate, "level-up, evolution"),
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s), count: 3), spacing: Tokens.Space.s) {
            ForEach(Self.meanings, id: \.0) { flood, meaning in
                VStack(alignment: .leading, spacing: 2) {
                    Text(flood.rawValue)
                        .font(Typography.displayS)
                    Text(meaning)
                        .font(Typography.caption)
                }
                .foregroundStyle(Tokens.ink)
                .padding(Tokens.Space.s)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .bottomLeading)
                .background { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).fill(flood.color) }
                .environment(\.colorScheme, flood.inkScheme)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
