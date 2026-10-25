import SwiftUI

/// The one primary action per screen: the ink pill. It is the only filled control on a screen.
/// Disabled = the pill at 22 % with a dimmer label (the caller adds a glyph so it is not colour-only).
struct FatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FatButtonBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FatButtonStyle {
    static var fat: FatButtonStyle { FatButtonStyle() }
}

private struct FatButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var scale: CGFloat {
        guard isEnabled else { return 1 }
        if isPressed { return 0.97 }
        return isHovering ? 1.015 : 1
    }

    var body: some View {
        label
            .font(Typography.button)
            .foregroundStyle(isEnabled ? Tokens.paper : Tokens.ink.opacity(0.55))
            .padding(.horizontal, Tokens.Space.xl)
            .frame(maxWidth: .infinity, minHeight: Tokens.pillHeight)
            .background {
                Capsule().fill(isEnabled ? Tokens.ink : Tokens.ink.opacity(0.22))
            }
            .scaleEffect(scale)
            .contentShape(Capsule())
            .onHover { isHovering = $0 }
            .animation(Motion.animation(.tap, reduceMotion: reduceMotion), value: scale)
    }
}
