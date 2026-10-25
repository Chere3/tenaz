import SwiftUI

/// The paper sheet on the exam's indigo flood: passages, answers and option rows sit on it so long
/// text reads as ink on paper. The flood flips the colour scheme to light ink, so the sheet puts the
/// scheme back to light inside itself: `Tokens.paper` is the cream page and `Tokens.ink` is dark.
struct ExamSheet: ViewModifier {
    var radius: CGFloat = Tokens.Radius.sheet
    var fill: Color = Tokens.paper

    func body(content: Content) -> some View {
        content
            .background { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill) }
            .environment(\.colorScheme, .light)
    }
}

extension View {
    func examSheet(radius: CGFloat = Tokens.Radius.sheet) -> some View {
        modifier(ExamSheet(radius: radius))
    }
}
