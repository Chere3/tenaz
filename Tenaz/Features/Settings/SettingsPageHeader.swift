import SwiftUI

/// Page title with one plain sentence under it.
struct SettingsPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(title)
                .font(Typography.displayM)
                .foregroundStyle(Tokens.ink)
            Text(subtitle)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Tokens.brand)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Tokens.Space.xs)
    }
}
