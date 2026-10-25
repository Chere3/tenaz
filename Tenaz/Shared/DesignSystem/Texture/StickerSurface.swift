import SwiftUI

/// A flat surface: fill only. No outline and no shadow (Full Bleed separates with colour and space).
/// Under Increase Contrast a thin ink edge appears so the surface stays findable.
/// The `depth` and `outlined` parameters are kept so older call sites compile; they are ignored.
struct StickerSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let fill: Color
    var depth: CGFloat = 0
    var outlined = true
    var lineWidth: CGFloat?
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background { shape.fill(fill) }
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(Tokens.ink, lineWidth: Tokens.strokeIncreased)
                }
            }
    }
}

extension View {
    func sticker(_ fill: Color = Tokens.card, radius: CGFloat = Tokens.Radius.card, depth: CGFloat = 0, outlined: Bool = true) -> some View {
        modifier(StickerSurface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), fill: fill, depth: depth, outlined: outlined))
    }

    func stickerPill(_ fill: Color, depth: CGFloat = 0) -> some View {
        modifier(StickerSurface(shape: Capsule(), fill: fill, depth: depth))
    }
}
