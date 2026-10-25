import Foundation

/// Where the review screen is.
enum ReviewPhase: Equatable {
    case loading
    /// Nothing to review (today's set is empty, or the database is unavailable).
    case empty(message: String)
    case question(ReviewCardModel)
    case feedback(ReviewCardModel, ReviewFeedback)
    /// Natural stopping point after the daily words: keep going or stop.
    case checkpoint
    /// Only learning-step cards are left and none is due yet.
    case waiting(until: Date)
    case done(ReviewSummary)
}

extension ReviewPhase {
    /// The card on screen (question or feedback), so both phases share one view identity.
    var card: ReviewCardModel? {
        switch self {
        case let .question(card), let .feedback(card, _): card
        default: nil
        }
    }

    var feedback: ReviewFeedback? {
        if case let .feedback(_, feedback) = self {
            feedback
        } else { nil }
    }
}
