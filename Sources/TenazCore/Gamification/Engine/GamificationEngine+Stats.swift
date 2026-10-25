import Foundation
import GRDB

extension GamificationEngine {
    /// Fills `AchievementStats` from what the engine has recorded plus the latest learning snapshot.
    func achievementStats(_ db: Database, mascot m: MascotStateRecord, streak: StreakSummary) throws -> AchievementStats {
        var s = AchievementStats()
        s.stage = m.stage
        s.bestCombo = m.bestCombo
        s.flyMentioned = m.flyMentioned
        s.bestStreak = streak.best
        s.correctRetrievals = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(correctRetrievals), 0) FROM day_stat") ?? 0
        s.nightReviews = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(nightReviews), 0) FROM day_stat") ?? 0
        s.freezesUsed = try Int.fetchOne(db, sql: "SELECT count(*) FROM day_stat WHERE frozen = 1") ?? 0

        func eventCount(_ kind: String) throws -> Int {
            try Int.fetchOne(db, sql: "SELECT count(*) FROM mascot_event WHERE kind = ?", arguments: [kind]) ?? 0
        }
        s.gateParagraphs = try eventCount("writing.gate")
        s.paragraphs = try eventCount("writing.paragraph")
        s.repairsCompleted = try eventCount("healed")

        let qualified = Set(try Int.fetchAll(db, sql: "SELECT day FROM day_stat WHERE qualified = 1"))
        s.weekendRun = ConsistencyStats.longestWeekendRun(qualified)
        s.weeklyGoalRun = ConsistencyStats.longestWeeklyGoalRun(qualified)
        s.phoenix = ConsistencyStats.phoenix(qualified)

        // Early Axolotl: the day's first activity before 07:00 local time.
        let starts = try Row.fetchAll(db, sql: "SELECT day, firstActivityAt FROM day_stat WHERE firstActivityAt IS NOT NULL")
        let earlyDays = starts.compactMap { row -> Int? in
            let ms: Int64 = row["firstActivityAt"]
            let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: Double(ms) / 1000))
            return hour < 7 ? row["day"] : nil
        }
        s.earlyDayRun = ConsistencyStats.longestRun(Set(earlyDays))

        let lastMercyDay = try Int.fetchOne(db, sql: "SELECT MAX(day) FROM penalty_event WHERE mercyUsed = 1")
        s.qualifiedDaysWithoutMercy = qualified.filter { $0 > (lastMercyDay ?? 0) }.count

        if let json = try? JSONSerialization.jsonObject(with: Data(m.cosmetics.utf8)) as? [String: [String]] {
            s.cosmeticsOwned = json["owned"]?.count ?? 0
            s.cosmeticsEquipped = json["equipped"]?.count ?? 0
        }

        s.exams = try ExamOutcomeRecord.order(Column("ts")).fetchAll(db).map {
            ExamCredit(attemptId: $0.refId, kind: $0.kind, band: $0.band, sectionBands: [$0.bestSectionBand], integrity: $0.integrity)
        }
        s.learning = try Self.meta(db, Self.learningKey) ?? LearningSnapshot()
        return s
    }
}
