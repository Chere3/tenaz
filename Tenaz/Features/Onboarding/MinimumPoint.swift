import SwiftUI

/// One short line with a glyph.
struct MinimumPoint: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.brand)
                .frame(width: 22)
        }
    }
}
