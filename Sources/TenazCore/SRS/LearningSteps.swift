import Foundation

/// Minute-level steps before a card enters (or re-enters) long-term review, as in py-fsrs 6.3.2.
public struct LearningSteps: Equatable, Sendable {
    /// Steps for a new card, in seconds.
    public var learning: [TimeInterval]
    /// Steps after a lapse, in seconds.
    public var relearning: [TimeInterval]

    public init(learning: [TimeInterval], relearning: [TimeInterval]) {
        self.learning = learning
        self.relearning = relearning
    }

    /// py-fsrs defaults: new `[1 min, 10 min]`, relearning `[10 min]`.
    public static let standard = LearningSteps(learning: [60, 600], relearning: [600])
    /// Pure long-term scheduling (the fluo golden table).
    public static let none = LearningSteps(learning: [], relearning: [])
}
