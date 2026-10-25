/// What one event changed, for stickers, banners and Tena's reaction.
public struct GamificationEffects: Equatable, Sendable {
    public var xp = 0
    public var scales = 0
    public var vitalityDelta = 0
    public var spiritDelta = 0
    public var level: LevelProgress
    public var leveledUp = false
    public var stage = 0
    public var stageAdvanced = false
    public var mood: MascotMood = .neutral
    public var unlocked: [AchievementDefinition] = []
    /// Quests whose progress moved, after the change.
    public var questProgress: [QuestRecord] = []
    public var questsCompleted: [QuestRecord] = []
    public var penalty: AppliedPenalty?
    public var recoveryMode = false
    public var welcomeBack = false
    public var dayQualified = false
    public var streak = StreakSummary()
    /// Limbs regrown so far while a repair task runs (0...4); nil when none is running.
    public var repairLimbs: Int?
    public var repairCompleted = false
}
