import SwiftUI

/// Display type. It used to carry a mis-registered second ink at rest; Full Bleed keeps titles clean,
/// so `secondInk` and `offset` are ignored (kept so older call sites compile).
struct MisprintText: View {
    let text: String
    var font: Font = Typography.displayL
    var ink: Color = Tokens.ink

    init(_ text: String, font: Font = Typography.displayL, ink: Color = Tokens.ink, secondInk: Color = Tokens.accent, offset: CGSize = .zero) {
        self.text = text
        self.font = font
        self.ink = ink
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(ink)
    }
}
