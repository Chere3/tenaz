import SwiftUI

/// The Full Bleed signature: the whole window is one colour, and the colour is the state.
/// One flood per screen. Never use a flood for decoration, or colour stops meaning state.
enum Flood: String, CaseIterable, Sendable {
    /// Your turn: words are due, a question is waiting.
    case turn
    /// Right answer; everything done for today.
    case good
    /// Wrong answer: shows the fix, warm, never an alarm.
    case fix
    /// Exams and the writing gate.
    case serious
    /// The streak is about to break, a penalty is pending.
    case risk
    /// Level-up and evolution only.
    case celebrate

    var color: Color {
        switch self {
        case .turn: Tokens.floodTurn
        case .good: Tokens.floodGood
        case .fix: Tokens.floodFix
        case .serious: Tokens.floodSerious
        case .risk: Tokens.floodRisk
        case .celebrate: Tokens.floodCelebrate
        }
    }

    /// Serious and risk carry light ink; the others carry dark ink, in both appearances.
    var inkScheme: ColorScheme {
        switch self {
        case .serious, .risk: .dark
        default: .light
        }
    }
}

private struct FloodBackground: ViewModifier {
    let flood: Flood?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, flood?.inkScheme ?? scheme)
            .background {
                ZStack {
                    (flood?.color ?? Tokens.paper)
                    PaperGrain(density: flood == nil ? 1 : 0.6)
                        .environment(\.colorScheme, flood?.inkScheme ?? scheme)
                }
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: flood)
            }
    }
}

extension View {
    /// Fills the window with `flood` and flips the colour scheme inside it so every Token reads on it.
    /// nil = plain paper (rest screens). Changing the flood crossfades in 220 ms.
    func flood(_ flood: Flood?) -> some View {
        modifier(FloodBackground(flood: flood))
    }
}
