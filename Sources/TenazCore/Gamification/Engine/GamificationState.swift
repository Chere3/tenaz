/// Everything Home, the popover and the Achievements/Quests/Contract screens show.
public struct GamificationState: Equatable, Sendable {
    public var level: LevelProgress
    public var scales: Int
    public var mascot: MascotStateRecord
    public var stageName: String
    public var mood: MascotMood
    public var streak: StreakSummary
    public var today: DayStatRecord
    public var quests: [QuestRecord]
    public var weeklyQuest: QuestRecord?
    public var achievements: [AchievementProgress]
    public var contract: Contract
    public var mercyLeft: Int
    public var recoveryMode: Bool
    public var welcomeBack: Bool
    /// Tena holds stage 3 from the prior but the placement came out lower: show "catching up".
    public var catchingUp: Bool
    public var microGrowth: MicroGrowth
    /// Rules the weekly review should suggest turning off (escape rate > 60% for 2 weeks).
    public var suggestedToDisable: [String]
}
