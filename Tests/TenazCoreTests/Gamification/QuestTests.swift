import Testing
@testable import TenazCore

struct QuestTests {
    @Test func adaptiveTargets() {
        #expect(abs(QuestTuning.nextMultiplier(1.0, done: 13, total: 14) - 1.10) < 1e-9) // >85%
        #expect(abs(QuestTuning.nextMultiplier(1.0, done: 6, total: 14) - 0.85) < 1e-9) // <50%
        #expect(QuestTuning.nextMultiplier(1.0, done: 10, total: 14) == 1.0) // in the flow band
        #expect(QuestTuning.nextMultiplier(1.0, done: 0, total: 2) == 1.0) // too little data
        #expect(QuestTuning.nextMultiplier(1.95, done: 14, total: 14) == 2.0) // clamped
        #expect(QuestTuning.nextMultiplier(0.52, done: 0, total: 14) == 0.5)
        let hard = QuestGenerator.daily(day: 20261102, dueCount: 80, weakestCategory: "articles", multiplier: 1.5)
        #expect(hard[0].target == 30) // core = min(due, 30), never adapted
        #expect(hard[1].target == 5) // skill 3 × 1.5, rounded
        #expect(hard[1].title.contains("articles"))
        #expect(hard[2].target == 15)
        #expect(hard[2].mysteryDrop)
        let easy = QuestGenerator.daily(day: 20261102, dueCount: 2, weakestCategory: nil, multiplier: 0.5)
        #expect(easy[0].target == QuestGenerator.coreMinimum)
        #expect(easy[1].target == 2)
    }

    @Test func multiplierRisesAfterAWeekOfSuccess() throws {
        let f = try GamificationFixture()
        for _ in 0..<7 {
            for q in try f.state.quests where q.slot != .core {
                try f.engine.database.writer.write { db in
                    try db.execute(sql: "UPDATE quest SET done = 1 WHERE id = ?", arguments: [q.id])
                }
            }
            f.advance(days: 1)
        }
        #expect(try f.state.mascot.questMultiplier > 1.0)
    }

    @Test func dailyQuestsGeneratedAtFourAndProgress() throws {
        let f = try GamificationFixture()
        try f.engine.updateLearning(LearningSnapshot(dueCount: 6))
        f.advance(days: 1) // new day: generated from the live due count
        let s = try f.state
        #expect(s.quests.map(\.slot) == [.core, .skill, .stretch])
        #expect(s.weeklyQuest?.slot == .weekly)
        let core = s.quests[0]
        #expect(core.target == 6)
        var completed: [QuestRecord] = []
        for i in 0..<6 { completed += try f.review("q\(i)").questsCompleted }
        #expect(completed.map(\.slot) == [.core])
        #expect(try f.state.quests[0].done)
    }
}
