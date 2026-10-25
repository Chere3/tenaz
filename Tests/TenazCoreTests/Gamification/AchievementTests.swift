import Testing
@testable import TenazCore

struct AchievementTests {
    static let defs = try! AchievementDefinition.loadAll(from: ContentTests.contentRoot.appendingPathComponent("achievements.json"))

    func def(_ id: String) -> AchievementDefinition { Self.defs.first { $0.id == id }! }

    @Test func bundledDefinitionsAreComplete() {
        #expect(Self.defs.count == 53)
        #expect(Set(Self.defs.map(\.id)).count == 53)
        let computable = Self.defs.filter { AchievementEvaluator.supportedKeys.contains($0.condition) }
        #expect(computable.count >= 30)
        #expect(Self.defs.filter(\.hidden).count == 6)
        for d in Self.defs { #expect((0...200).contains(d.reward.xp), "\(d.id)") }
    }

    @Test func conditions() {
        var s = AchievementStats()
        #expect(!AchievementEvaluator.isUnlocked(def("first-blood"), s))
        s.correctRetrievals = 10
        #expect(AchievementEvaluator.isUnlocked(def("first-blood"), s))
        s.bestStreak = 7
        #expect(AchievementEvaluator.isUnlocked(def("week-one"), s))
        #expect(!AchievementEvaluator.isUnlocked(def("fortnight"), s))
        s.learning.masteredNotes = 100
        #expect(AchievementEvaluator.isUnlocked(def("sticky-notes"), s))
        s.stage = 3
        #expect(AchievementEvaluator.isUnlocked(def("coming-of-age"), s))
        #expect(!AchievementEvaluator.isUnlocked(def("full-crest"), s))
        // Exams: only verified ones count, and "in a row" means consecutive.
        s.exams = [ExamCredit(kind: .weeklyMock, band: 3.0, integrity: .clean),
                   ExamCredit(kind: .weeklyMock, band: 4.0, integrity: .violation),
                   ExamCredit(kind: .weeklyMock, band: 3.5, integrity: .warning)]
        #expect(AchievementEvaluator.isUnlocked(def("b1-certified"), s))
        #expect(!AchievementEvaluator.isUnlocked(def("b2-gate"), s))
        #expect(AchievementEvaluator.isUnlocked(def("clean-room"), s))
        s.exams.append(ExamCredit(kind: .dailyCheck, band: 5, integrity: .clean)) // Daily Check is not a listed kind
        #expect(!AchievementEvaluator.isUnlocked(def("c1-horizon"), s))
        // Keys no area produces yet stay locked, and hidden ones read "???".
        #expect(AchievementEvaluator.value(def("rubber-duck"), s) == nil)
        let hidden = AchievementProgress(definition: def("night-owl"), unlockedAt: nil, value: 0)
        #expect(hidden.displayName == "???")
    }

    @Test func consistencyPatterns() {
        // 2 Nov 2026 is a Monday; 7 Nov a Saturday.
        let weekends = Set([20261107, 20261108, 20261114, 20261115])
        #expect(ConsistencyStats.longestWeekendRun(weekends) == 2)
        let back = Set([20261101, 20261110, 20261111, 20261112, 20261114, 20261115])
        #expect(ConsistencyStats.phoenix(back))
        #expect(ConsistencyStats.longestRun(Set([20261130, 20261201, 20261202])) == 3)
    }

    @Test func engineUnlocksAndRewards() throws {
        let f = try GamificationFixture()
        var unlocked: [String] = []
        for i in 0..<10 { unlocked += try f.review("a\(i)").unlocked.map(\.id) }
        #expect(unlocked.contains("first-blood"))
        let s = try f.state
        #expect(s.achievements.first { $0.id == "first-blood" }?.isUnlocked == true)
        #expect(s.achievements.count == 53)
        // Unlocked once only.
        #expect(try !f.review("a0").unlocked.map(\.id).contains("first-blood"))
    }
}
