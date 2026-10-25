import AppKit
import SwiftUI

/// Borderless panel that floats above everything, including full-screen apps, on every Space.
/// Level is `.screenSaver` (never the shielding level) so Force Quit and system dialogs still win;
/// no presentation-option flags are ever set, so Cmd-Tab, Force Quit and the Dock keep working.
final class OverlayPanel: NSPanel {
    var acceptsTyping = false
    override var canBecomeKey: Bool { acceptsTyping }
    override var canBecomeMain: Bool { false }

    init(frame: NSRect, interactive: Bool) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        hasShadow = false
        isMovable = false
        acceptsTyping = interactive
    }
}
