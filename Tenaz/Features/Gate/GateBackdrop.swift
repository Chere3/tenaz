import SwiftUI

/// Full-screen serious field (indigo) with the notification band cut out.
struct GateBackdrop: View {
    var flood: Flood = .serious

    var body: some View {
        ZStack {
            NotchedPage().fill(flood.color)
            PaperGrain(density: 0.6).clipShape(NotchedPage())
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
