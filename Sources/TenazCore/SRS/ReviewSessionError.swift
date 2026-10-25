import Foundation

public enum ReviewSessionError: Error, Equatable, Sendable {
    /// `submit` was called with no card on screen (call `next` first).
    case noCurrentCard
    /// The answer kind does not fit the card (e.g. typed text for a recognition card).
    case answerDoesNotFitCard
}
