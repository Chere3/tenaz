import SwiftUI

/// The app icon art (concept B, chosen 25 Oct 2026): Tena's head, tilted 8°, filling a flat flood.
/// The static icon is `Tenaz/Resources/AppIcon.icon` (yellow, happy). While Tenaz runs, `DockIcon`
/// draws this view with Tena's live mood on the flood Home is showing.
/// Geometry matches the .icon layer: Tena at 1.7x the tile, nudged (4, 145) of 1024 down-right
/// (checked row by row against the ictool render: within 0.3 %).
struct AppIconArt: View {
    let mood: TenaMood
    var flood: Flood = .turn
    /// Canvas side; the squircle is inset like every macOS icon (824 of 1024).
    var side: CGFloat = 512

    var body: some View {
        let tile = side * 824 / 1024
        ZStack {
            flood.color
            TenaView(mood: mood, stage: .juvenile, size: tile * 1.7, ground: false)
                .rotationEffect(.degrees(-8))
                .offset(x: tile * 4 / 1024, y: tile * 145 / 1024)
        }
        .frame(width: tile, height: tile)
        .clipShape(RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous))
        .frame(width: side, height: side)
        .environment(\.mascotStill, true)
        .environment(\.colorScheme, .light)
        .accessibilityHidden(true)
    }
}
