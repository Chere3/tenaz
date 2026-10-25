import SwiftUI

/// A one-line note (paused, unfinished, or the last result) with one text action. No capsule:
/// it reads as a sentence with a link.
struct PlacementBanner: View {
    let text: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xxs) {
            Text(text)
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Label(button, systemImage: "arrow.right")
                    .labelStyle(TrailingIcon())
            }
            .buttonStyle(InkTextButtonStyle(tint: Tokens.ink))
        }
    }
}

/// "Continue →": the arrow after the word.
private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.system(size: 12, weight: .bold))
        }
    }
}
