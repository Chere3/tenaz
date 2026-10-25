import SwiftUI

/// Transition state for stickers peeling onto the page.
struct PeelEffect: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.9 + 0.1 * progress, anchor: .bottomLeading)
            .rotationEffect(.degrees(-4 * (1 - progress)), anchor: .bottomLeading)
            .opacity(progress)
    }
}
