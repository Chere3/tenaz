import SwiftUI

/// A text to read: the title and the passage set straight on the flood, in ink, at a comfortable measure.
struct PassageCard: View {
    let title: String?
    let text: String

    var body: some View {
        SnapshotSafeScroll(hug: true) {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(Typography.displayS)
                        .foregroundStyle(Tokens.ink)
                }
                Text(text)
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .lineSpacing(9)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.disabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
