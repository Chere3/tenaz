import SwiftUI

/// The page: paper (or night stock) plus grain.
struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            ZStack {
                Tokens.paper
                PaperGrain()
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    func paperBackground() -> some View {
        modifier(PaperBackground())
    }
}
