import SwiftUI

/// A titled group of settings: no box. A hairline rule opens it, a sentence-case header names it, and
/// the rows inside are separated by hairlines. `systemImage` is kept for call sites and is not drawn.
struct SettingsCard<Content: View>: View {
    let title: String
    var systemImage: String?
    var note: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: Tokens.rule)
                .padding(.bottom, Tokens.Space.s)
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
            if let note {
                Text(note)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(subviews.indices, id: \.self) { i in
                        if i > 0 {
                            Rectangle().fill(Tokens.ink.opacity(0.08)).frame(height: Tokens.rule)
                        }
                        subviews[i].padding(.vertical, Tokens.Space.xs)
                    }
                }
            }
            .padding(.top, Tokens.Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
