import AppKit
import SwiftUI

/// The Dock icon follows Tena: her live mood on the flood Home shows (yellow your turn, mint done,
/// oxblood streak at risk). The Dock shows it while the main window is open (Tenaz is a menu-bar
/// app otherwise); Finder keeps the static AppIcon.icon.
enum DockIcon {
    private static var shown: String?

    static func update(_ summary: TodaySummary, now: Date = .now, force: Bool = false) {
        let flood = HomeBoard.flood(summary, now: now)
        let mood = HomeBoard.mood(summary, flood: flood)
        let key = "\(mood.rawValue).\(flood.rawValue)"
        guard force || key != shown else { return }
        let renderer = ImageRenderer(content: AppIconArt(mood: mood, flood: flood, side: 512))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return }
        NSApp.applicationIconImage = image
        shown = key
    }
}
