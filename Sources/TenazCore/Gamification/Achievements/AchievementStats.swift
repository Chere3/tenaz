/// The numbers achievements are judged on. The engine fills what it records itself; the
/// learning counts (introduced, mastered, leeches...) come from the scheduler via `LearningSnapshot`.
public struct AchievementStats: Equatable, Sendable {
    public var stage = 0
    public var correctRetrievals = 0
    public var gateParagraphs = 0
    public var paragraphs = 0
    public var bestCombo = 0
    public var bestStreak = 0
    public var freezesUsed = 0
    public var weekendRun = 0
    public var weeklyGoalRun = 0
    public var earlyDayRun = 0
    public var phoenix = false
    public var nightReviews = 0
    public var repairsCompleted = 0
    public var qualifiedDaysWithoutMercy = 0
    public var cosmeticsOwned = 0
    public var cosmeticsEquipped = 0
    public var flyMentioned = false
    /// Oldest first.
    public var exams: [ExamCredit] = []
    public var learning = LearningSnapshot()

    public init() {}
}
