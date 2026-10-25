import SwiftUI

/// The app icon art: the full Juvenile figure, tilted 8°, on a flat flood, cut by the tile's bottom edge at
/// the belly with all six gill fans inside the squircle (0.94 of the tile). The static icon is
/// `Tenaz/Resources/AppIcon.icon` (yellow, happy). While Tenaz runs, `DockIcon` draws this view with
/// Tena's live mood on the flood Home is showing.
/// Geometry matches the .icon layer (`scale`, `offset` below), checked against the ictool render.
struct AppIconArt: View {
    /// Tena's frame side as a share of the tile, and her nudge in 1024ths of it (down-right). The .icon
    /// layer uses the same numbers: `scale` = this / 2 (its 2048 px layer), `translation-in-points` = offset.
    static let scale: CGFloat = 0.94
    static let offset = CGSize(width: 0, height: 150)

    let mood: TenaMood
    var flood: Flood = .turn
    /// Canvas side; the squircle is inset like every macOS icon (824 of 1024).
    var side: CGFloat = 512

    var body: some View {
        let tile = side * 824 / 1024
        ZStack {
            flood.color
            TenaView(mood: mood, stage: .juvenile, size: tile * Self.scale)
                .rotationEffect(.degrees(-8))
                .offset(x: tile * Self.offset.width / 1024, y: tile * Self.offset.height / 1024)
        }
        .frame(width: tile, height: tile)
        .clipShape(RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous))
        .frame(width: side, height: side)
        .environment(\.mascotStill, true)
        .environment(\.colorScheme, .light)
        .accessibilityHidden(true)
    }
}
