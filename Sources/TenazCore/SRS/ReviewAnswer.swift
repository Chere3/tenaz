import Foundation

/// What the learner gave for a card.
public enum ReviewAnswer: Equatable, Sendable {
    /// Recognition: the chosen option index.
    case choice(Int)
    /// Cloze, recall, collocation, spelling.
    case typed(String)
    /// A rating decided elsewhere: the Claude rubric for P, speech match for S.
    case graded(Rating)

    var text: String? {
        switch self {
        case let .choice(i): String(i)
        case let .typed(s): s
        case .graded: nil
        }
    }
}
