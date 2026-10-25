import SwiftUI

/// A titled block of the weekly review: a sentence-case label over the content, set off by a
/// hairline above. No box.
struct ReviewCard<Content: View>: View {
    let title: String
    let systemImage: String
    var fill: Color = Tokens.card
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            ProgressRule().padding(.bottom, Tokens.Space.xs)
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
