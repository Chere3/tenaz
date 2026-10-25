import AppKit
import SwiftUI

/// Hosting view for overlay panels: the first click on a button acts at once instead of only
/// focusing the non-activating panel (Tenaz is an accessory app, so it is rarely active).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
