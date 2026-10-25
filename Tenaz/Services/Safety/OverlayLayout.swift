import AppKit

/// Where a surface's panel sits. Poster and gate leave the top-right notification band uncovered
/// (400 × 160 pt under the menu bar), so an incoming-call banner stays visible (PLAN F1, F2).
enum OverlayLayout: Equatable {
    /// Paper card over most of the screen, below the notification band.
    case poster
    /// Small card in the bottom-right corner.
    case sticker
    /// The 20-second "Words in 20 s" note: bottom-right, never key.
    case toast
    /// The gate: every screen; the main one gets the page, the others a dim backdrop.
    case fullScreen

    static let notificationBand = CGSize(width: 400, height: 160)
    static let stickerSize = CGSize(width: 400, height: 262)
    static let toastSize = CGSize(width: 380, height: 110)

    var isInteractive: Bool { self != .toast }

    func frame(on screen: NSScreen) -> NSRect {
        let vf = screen.visibleFrame
        switch self {
        case .fullScreen:
            return screen.frame
        case .poster:
            let top = vf.maxY - Self.notificationBand.height - 8
            let width = min(1180, vf.width * 0.74)
            let height = min(760, (top - vf.minY) * 0.94)
            return NSRect(x: vf.midX - width / 2, y: vf.minY + (top - vf.minY - height) / 2, width: width, height: height)
        case .sticker:
            return NSRect(x: vf.maxX - Self.stickerSize.width - 12, y: vf.minY + 12, width: Self.stickerSize.width, height: Self.stickerSize.height)
        case .toast:
            return NSRect(x: vf.maxX - Self.toastSize.width - 12, y: vf.minY + 12, width: Self.toastSize.width, height: Self.toastSize.height)
        }
    }

    /// The screen under the pointer (where the learner is looking), else the main screen.
    static func activeScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
