/// What the overlay card shows right now.
enum OverlayPhase: Equatable {
    /// Waiting for the answer.
    case asking
    /// Remembered: green, "+XP", Tena blinks. Moves on by itself.
    case correct(xp: Int)
    /// Forgotten: red, the right answer big, their answer struck through, "back in 1 min".
    case wrong(expected: String, given: String)
    /// The batch is over (3 of 3 stamp).
    case done(correct: Int, total: Int, xp: Int)
}
