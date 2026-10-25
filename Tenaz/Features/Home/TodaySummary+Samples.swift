/// Fixed data for snapshots and previews.
extension TodaySummary {
    /// A week in: placement done (band 3.5), a 4-day streak, part of today's minimum done.
    static let sample = TodaySummary(
        mood: .happy, stage: .juvenile, stageName: "Juvenile", band: 3.5,
        streakDays: 4, bestStreak: 4, last7: [false, true, false, true, true, true, false],
        vitality: 82, spirit: 74, level: 3, xpIntoLevel: 132, xpForLevel: 233,
        correctToday: 7, productionsToday: 0, qualifiedToday: false, todaySetCount: 14,
        quests: [
            TodayQuest(id: "q1", title: "Clear your set: 14 words", progress: 7, target: 14, done: false, rewardXP: 80),
            TodayQuest(id: "q2", title: "Write 2 sentences", progress: 0, target: 2, done: false, rewardXP: 60),
            TodayQuest(id: "q3", title: "8 right in a row", progress: 8, target: 8, done: true, rewardXP: 100),
        ],
        write: TodayWritePrompt(id: "life-paragraphs-002",
                                prompt: "Describe a meeting in English that went well for you recently. What made it work?",
                                mustUse: ["based on", "manage to", "although"], minWords: 40),
        placementTaken: true, placementMinutes: 48
    )

    /// A text-based kind for the `write-text` snapshot: the text to rewrite, the instruction, the kind's placeholder.
    static let textSample = TodayWritePrompt(
        id: "sample-rewrite", prompt: "Your message to the planning team sounds too blunt.", mustUse: ["could you"], minWords: 40,
        kind: .rewrite,
        text: "Forecast is wrong again. Fix the numbers for site 3 today, I need them before the call. "
            + "Nobody told me the dates changed.")

    /// The first morning: onboarding done, Tena just hatched, no placement yet.
    static let firstRun = TodaySummary(
        mood: .curious, stage: .hatchling, stageName: "Hatchling", band: nil,
        streakDays: 0, bestStreak: 0, last7: Array(repeating: false, count: 7),
        vitality: 80, spirit: 80, level: 1, xpIntoLevel: 0, xpForLevel: 100,
        correctToday: 0, productionsToday: 0, qualifiedToday: false, todaySetCount: 5,
        quests: [
            TodayQuest(id: "q1", title: "Clear your set: 5 words", progress: 0, target: 5, done: false, rewardXP: 50),
            TodayQuest(id: "q2", title: "Write 1 sentence", progress: 0, target: 1, done: false, rewardXP: 50),
            TodayQuest(id: "q3", title: "5 right in a row", progress: 0, target: 5, done: false, rewardXP: 80),
        ],
        write: TodayWritePrompt(id: "life-paragraphs-001",
                                prompt: "What is the first thing you did today, and how did it set the mood for the rest of your day?",
                                mustUse: ["although", "right now"], minWords: 40),
        placementTaken: false, placementMinutes: 52
    )
}
