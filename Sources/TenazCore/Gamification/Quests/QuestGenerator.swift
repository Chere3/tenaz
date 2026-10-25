/// Builds the day's three quests (at the 04:00 boundary) and the week's quest from live data.
public enum QuestGenerator {
    public static let coreCap = 30
    public static let coreMinimum = 5
    public static let skillBase = 3
    public static let stretchBase = 10

    /// Readable names for the error-ledger categories the skill quest rotates through.
    static let categoryNames: [String: String] = [
        "articles": "articles (a / an / the)",
        "prepositions": "prepositions",
        "verbPatterns": "verb patterns (to + verb / -ing)",
        "presentPerfect": "the present perfect",
        "agreement": "subject-verb agreement",
        "falseFriends": "false friends",
        "intensifiers": "intensifiers",
        "fillerLike": "fewer fillers (\"like\")",
    ]

    /// `dueCount` comes from the scheduler; `weakestCategory` from the error ledger (nil before M8).
    /// The core target is never adapted (it follows the real due set); skill and stretch are.
    public static func daily(day: Int, dueCount: Int, weakestCategory: String?, multiplier: Double) -> [QuestRecord] {
        let core = max(coreMinimum, min(dueCount, coreCap))
        let skill = QuestTuning.scaled(skillBase, by: multiplier)
        let stretch = QuestTuning.scaled(stretchBase, by: multiplier)
        let skillTitle: String
        let skillTemplate: String
        if let cat = weakestCategory {
            skillTemplate = "skill.weakness.\(cat)"
            skillTitle = "Write \(skill) sentences practising \(categoryNames[cat] ?? cat)"
        } else {
            skillTemplate = "skill.range"
            skillTitle = "Use \(skill) words you learned this week in your own sentences"
        }
        return [
            QuestRecord(day: day, slot: .core, template: "core.clearDue", title: "Clear today's set: \(core) reviews",
                        metric: .reviewsDone, target: core, rewardXP: 80, rewardScales: 10),
            QuestRecord(day: day, slot: .skill, template: skillTemplate, title: skillTitle,
                        metric: .productions, target: skill, rewardXP: 80, rewardScales: 8),
            QuestRecord(day: day, slot: .stretch, template: "stretch.combo", title: "Get \(stretch) answers right in a row",
                        metric: .comboToday, target: stretch, rewardXP: 120, rewardScales: 12, mysteryDrop: true),
        ]
    }

    public static func weekly(weekStart: Int) -> QuestRecord {
        QuestRecord(day: weekStart, slot: .weekly, template: "weekly.meetingPrep",
                    title: "Meeting prep: a 3-minute spoken summary of your week",
                    metric: .spokenSummaries, target: 1, rewardXP: 150, rewardScales: 30)
    }
}
