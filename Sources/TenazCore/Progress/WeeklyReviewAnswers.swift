/// What the learner writes in the weekly review (stored as JSON in `weekly_review.answers`).
public struct WeeklyReviewAnswers: Codable, Equatable, Sendable {
    /// "What worked this week?" in one line.
    public var whatWorked: String
    /// Rules they want to change at the next calm Contract session (raw rule ids).
    public var rulesToRethink: [String]

    public init(whatWorked: String = "", rulesToRethink: [String] = []) {
        self.whatWorked = whatWorked
        self.rulesToRethink = rulesToRethink
    }
}
