import SwiftUI

/// Esc on a button, only when enabled (a text field that handles Esc itself turns it off).
struct CancelShortcut: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyboardShortcut(.cancelAction)
        } else {
            content
        }
    }
}
