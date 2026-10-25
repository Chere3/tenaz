import SwiftUI

/// Tena in small sizes (lists, sidebar) and the menu-bar glyphs. Hero Tena is big and cropped by an edge.
struct GalleryPrint: View {
    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.m) {
            TenaView(mood: .happy, stage: .juvenile, size: 96)
            TenaView(mood: .proud, stage: .adult, size: 96)
            TenaView(mood: .focused, stage: .juvenile, size: 96)
            Spacer(minLength: 0)
            HStack(spacing: Tokens.Space.s) {
                ForEach(TenaGlyphState.allCases, id: \.self) { state in
                    TenaGlyph(state: state, size: 36)
                        .foregroundStyle(Tokens.ink)
                }
            }
        }
    }
}
