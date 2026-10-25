import SwiftUI

/// A titled block in the design gallery: sentence-case label, a hairline, then the specimens.
struct GallerySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: Tokens.rule)
            Text(title)
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
            content
        }
    }
}
