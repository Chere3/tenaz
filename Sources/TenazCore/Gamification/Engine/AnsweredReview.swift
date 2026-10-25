/// One answered review card.
public struct AnsweredReview: Equatable, Sendable {
    public var cardId: String
    public var correct: Bool
    /// FSRS difficulty (1-10) of the card before this review.
    public var difficulty: Double
    /// Failed earlier this session and now recalled: +3 XP instead of the full amount.
    public var correctedAfterFail: Bool
    /// Hinted answers do not count toward the repair task.
    public var usedHint: Bool

    public init(cardId: String, correct: Bool, difficulty: Double = 5, correctedAfterFail: Bool = false, usedHint: Bool = false) {
        self.cardId = cardId
        self.correct = correct
        self.difficulty = difficulty
        self.correctedAfterFail = correctedAfterFail
        self.usedHint = usedHint
    }
}
