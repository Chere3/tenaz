/// Experiment-log outcome of one rule firing (PLAN F10, research 02 §8).
public enum PenaltyOutcome: String, Codable, Sendable {
    /// The rule fired and its cost or task was applied.
    case fired
    /// Shown, then dismissed without acting.
    case dismissed
    /// The learner used an escape hatch (emergency skip) to get out of it.
    case escaped
    /// Not charged: daily cap, recovery mode or welcome-back day.
    case waived
}
