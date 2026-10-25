import SwiftUI
import TenazCore

/// One theme's full sheet of tokens and components: Full Bleed.
struct GallerySheet: View {
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Bleed")
                    .font(Typography.display(56))
                    .foregroundStyle(Tokens.ink)
                Text("\(palette.name) sheet · one flood per screen, the colour is the state")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
            GallerySection(title: "Floods") { GalleryFloods() }
            GallerySection(title: "Type scale") { GalleryType() }
            GallerySection(title: "Inks") { GalleryInks(palette: palette) }
            GallerySection(title: "Space and shape") { GalleryShapes() }
            GallerySection(title: "Controls") { GalleryControls() }
            GallerySection(title: "Feedback, meters and bands") { GalleryFeedback() }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 640, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .paperBackground()
    }
}
