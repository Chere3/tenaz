/// What a quest counts. The engine advances these from gamification events.
public enum QuestMetric: String, Codable, Sendable {
    case reviewsDone
    case productions
    /// Best run of correct answers today (progress is the max, not a sum).
    case comboToday
    case spokenSummaries
}
