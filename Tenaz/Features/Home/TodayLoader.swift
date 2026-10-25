import Foundation
import GRDB
import TenazCore

/// Builds `TodaySummary` from the live stores. Every part degrades on its own: a missing database
/// gives a fresh egg with no set, never a crash.
enum TodayLoader {
    static func load(_ env: AppEnvironment, now: Date = .now) -> TodaySummary {
        let today = DayBoundary.day(for: now)
        let setCount = (try? env.reviewStore?.todaySet(now: now).count) ?? 0
        let back = setCount == 0 ? comingBack(env.database, now: now) : nil
        let placement = placementStatus(env.database)
        let placementBlueprint = env.blueprints.blueprint(for: .placement)
        let minutes = Int((placementBlueprint?.nominalMinutes ?? 45).rounded())
        var summary = TodaySummary(
            mood: .neutral, stage: .egg, stageName: TenaStage.egg.title, band: placement.band,
            streakDays: 0, bestStreak: 0, last7: Array(repeating: false, count: 7), vitality: 80, spirit: 80,
            level: 1, xpIntoLevel: 0, xpForLevel: 100, correctToday: 0, productionsToday: 0, qualifiedToday: false,
            todaySetCount: setCount, comingBack: back, quests: [], write: writePrompt(env.content, database: env.database, now: now),
            placementTaken: placement.taken, placementInProgress: placement.inProgress, placementMinutes: minutes
        )
        summary.placementParts = placementBlueprint?.sections.count ?? 7
        summary.dailyCheckMinutes = Int((env.blueprints.blueprint(for: .daily)?.nominalMinutes ?? 8).rounded())
        guard let engine = env.gamification,
              let state = try? engine.state(context: MoodContext(dueCount: placement.taken ? setCount : 0)) else { return summary }
        summary.mood = TenaMood(rawValue: state.mood.rawValue) ?? .neutral
        summary.stage = TenaStage(rawValue: state.mascot.stage) ?? .egg
        summary.stageName = state.stageName
        summary.catchingUp = state.catchingUp
        summary.streakDays = state.streak.current
        summary.bestStreak = state.streak.best
        summary.vitality = state.mascot.vitality
        summary.spirit = state.mascot.spirit
        summary.level = state.level.level
        summary.xpIntoLevel = state.level.xpIntoLevel
        summary.xpForLevel = state.level.xpForLevel
        summary.correctToday = state.today.correctRetrievals
        summary.productionsToday = state.today.productions
        summary.qualifiedToday = state.today.qualified
        summary.welcomeBack = state.welcomeBack
        summary.quests = state.quests.map {
            TodayQuest(id: $0.id, title: $0.title, progress: $0.progress, target: $0.target, done: $0.done, rewardXP: $0.rewardXP)
        }
        summary.last7 = lastSevenDays(env.database, today: today)
        return summary
    }

    /// Taken = a public band exists (set by the placement) or a placement attempt finished.
    static func placementStatus(_ database: TenazDatabase?) -> (taken: Bool, inProgress: Bool, band: Double?) {
        guard let database else { return (false, false, nil) }
        let band = try? ExamStore(database: database).publicBand()
        let status = try? database.reader.read { db in
            try String.fetchOne(db, sql: "SELECT status FROM exam_attempt WHERE kind = ? ORDER BY startedAt DESC LIMIT 1",
                                arguments: [ExamKind.placement.rawValue])
        }
        let latest = status ?? nil
        return (band != nil || latest == "done", band == nil && latest == "running", band ?? nil)
    }

    /// Cards in a learning step due later in this learning day (before the next 04:00).
    static func comingBack(_ database: TenazDatabase?, now: Date) -> TodayComingBack? {
        guard let database else { return nil }
        let start = DayBoundary.start(ofDayContaining: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86400)
        let row = try? database.reader.read { db in
            try Row.fetchOne(db, sql: """
            SELECT COUNT(*) AS n, MIN(card.due) AS first FROM card JOIN note ON note.id = card.noteId
            WHERE card.state IN ('learning', 'relearning') AND card.due > ? AND card.due < ? AND note.suspended = 0
            """, arguments: [now.unixMilliseconds, end.unixMilliseconds])
        }
        guard let row, let first: Int64 = row["first"], let count: Int = row["n"], count > 0 else { return nil }
        return TodayComingBack(count: count, at: Date(unixMilliseconds: first))
    }

    static func lastSevenDays(_ database: TenazDatabase?, today: Int) -> [Bool] {
        let days = (0 ..< 7).map { LearningDays.adding($0 - 6, to: today) }
        let qualified = (try? database?.reader.read { db in
            try Int.fetchAll(db, sql: "SELECT day FROM day_stat WHERE qualified = 1 AND day >= ?", arguments: [days[0]])
        }) ?? []
        let set = Set(qualified)
        return days.map(set.contains)
    }

    /// The next `lifeParagraph` prompt of any kind, through `ExposurePicker` (surface `write`): nothing
    /// already shown on the gate, Write or an exam comes back until 90 % of the pool is used, and the
    /// kind differs from the last two writing prompts. A prompt shown on Write today and not answered
    /// yet stays, so Home and the sheet agree and reopening the sheet does not reshuffle.
    static func writePrompt(_ content: ContentLibrary, database: TenazDatabase? = nil, now: Date = .now) -> TodayWritePrompt? {
        let pool = content.items.filter { $0.type == .lifeParagraph && !($0.prompt ?? "").isEmpty && !$0.id.hasPrefix("placement") }
        guard !pool.isEmpty else { return nil }
        let history = (try? database.map { try ExposureStore(database: $0).all() }) ?? []
        let today = DayBoundary.day(for: now)
        if let last = history.last(where: { $0.surface == ExposureSurface.write.rawValue }),
           DayBoundary.day(for: Date(unixMilliseconds: last.ts)) == today,
           let item = pool.first(where: { $0.id == last.itemId }),
           !answeredOnWrite(item.id, since: last.ts, database: database) {
            return TodayWritePrompt(item)
        }
        // Seeded by the day and the history, so every refresh until the sheet opens gives the same prompt.
        var rng = SeededRandom(seed: UInt64(today) &* 1_000_003 &+ UInt64(history.count))
        let picker = ExposurePicker(surface: .write, library: content.items, history: history, now: now)
        return picker.pick(pool, rng: &rng).map(TodayWritePrompt.init)
    }

    static func answeredOnWrite(_ id: String, since ts: Int64, database: TenazDatabase?) -> Bool {
        let count = try? database?.reader.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM writing_entry WHERE surface = 'write' AND promptId = ? AND ts >= ?",
                             arguments: [id, ts])
        }
        return (count ?? nil ?? 0) > 0
    }
}
