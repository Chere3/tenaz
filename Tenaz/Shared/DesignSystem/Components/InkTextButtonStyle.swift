import SwiftUI

/// Secondary actions: text with a glyph, never filled. Ink at 8 % appears behind it on hover.
struct InkTextButtonStyle: ButtonStyle {
    var tint: Color = Tokens.brand

    func makeBody(configuration: Configuration) -> some View {
        InkTextButtonBody(label: configuration.label, isPressed: configuration.isPressed, tint: tint)
    }
}

extension ButtonStyle where Self == InkTextButtonStyle {
    static var ink: InkTextButtonStyle { InkTextButtonStyle() }
}

private struct InkTextButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let tint: Color
    @State private var isHovering = false

    var body: some View {
        label
            .font(Typography.textButton)
            .foregroundStyle(tint)
            .padding(.horizontal, Tokens.Space.s)
            .padding(.vertical, Tokens.Space.xs)
            .frame(minHeight: 32)
            .background {
                Capsule().fill(Tokens.ink.opacity(0.08)).opacity(isHovering || isPressed ? 1 : 0)
            }
            .opacity(isPressed ? 0.7 : 1)
            .contentShape(Capsule())
            .onHover { isHovering = $0 }
    }
}
