/// Counts only the scheduler knows (cards, FSRS state). The app passes the latest snapshot to
/// the engine; before the scheduler exists everything is zero and those achievements stay locked.
public struct LearningSnapshot: Codable, Equatable, Sendable {
    public var notesIntroduced = 0
    /// Notes with stability ≥ 21 d and the last 3 recalls correct (`StageConfig.isMastered`).
    public var masteredNotes = 0
    public var dueCount = 0
    public var oldestOverdueHours = 0.0
    public var leechesCleared = 0
    /// Recalls after an interval of more than 60 days.
    public var longIntervalRecalls = 0
    /// Recalls of a word failed 3+ times, 30+ days later.
    public var comebackRecalls = 0
    /// The weakest error-ledger category, for the skill quest.
    public var weakestCategory: String?

    public init(notesIntroduced: Int = 0, masteredNotes: Int = 0, dueCount: Int = 0, oldestOverdueHours: Double = 0,
                leechesCleared: Int = 0, longIntervalRecalls: Int = 0, comebackRecalls: Int = 0, weakestCategory: String? = nil) {
        self.notesIntroduced = notesIntroduced
        self.masteredNotes = masteredNotes
        self.dueCount = dueCount
        self.oldestOverdueHours = oldestOverdueHours
        self.leechesCleared = leechesCleared
        self.longIntervalRecalls = longIntervalRecalls
        self.comebackRecalls = comebackRecalls
        self.weakestCategory = weakestCategory
    }
}
