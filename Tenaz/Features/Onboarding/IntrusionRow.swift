import SwiftUI

/// One intrusive feature as a plain list row (no card). The page's footer says it all starts Off.
struct IntrusionRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Tokens.ink)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                Text(detail)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
        }
        .padding(.vertical, Tokens.Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityValue("off")
    }
}
