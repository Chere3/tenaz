import Foundation
import GRDB

/// The one API UI areas call for XP, streak, Tena, penalties, quests and achievements.
/// Each call is one database transaction; there is no in-memory state, so it is `Sendable` and
/// can be called from the main actor (writes are tiny) or anywhere else.
///
/// Before handling anything, every call settles the learning days that ended since the last call
/// (04:00 boundary): missed-minimum costs, Spirit decay, freezes, quests for today.
///
/// Penalties (PLAN F10): every rule ships off. Vitality and Scales drop only through the Response
/// cost rule (skips, abandoned gate, missed minimum, uncorroborated meeting claims) or the Exam
/// stake rule; with them off a missed day only moves Spirit, so Tena's mood. The -30 Vitality
/// daily cap, the Vitality floor of 15, recovery mode after 3 events, the soft freeze after 2
/// missed days and the welcome-back pause apply to all. XP and level are never reduced by anything.
public final class GamificationEngine: Sendable {
    public let database: TenazDatabase
    public let stages: StageConfig
    public let achievements: [AchievementDefinition]
    let clock: any TenazClock
    let calendar: Calendar

    static let learningKey = "gamification.learning"
    static let evidenceKey = "gamification.stageEvidence"
    static let justHealedWindowMs: Int64 = 3600 * 1000
    static let ledToSessionWindowMs: Int64 = 30 * 60 * 1000

    public init(database: TenazDatabase, stages: StageConfig, achievements: [AchievementDefinition],
                clock: any TenazClock = SystemClock(), calendar: Calendar = .current) {
        self.database = database
        self.stages = stages
        self.achievements = achievements
        self.clock = clock
        self.calendar = calendar
    }

    /// Loads `config/stages.json` and `achievements.json` from a `Content` folder.
    public static func bundled(database: TenazDatabase, contentRoot: URL, clock: any TenazClock = SystemClock(),
                               calendar: Calendar = .current) throws -> GamificationEngine {
        GamificationEngine(
            database: database,
            stages: try StageConfig.load(from: contentRoot.appendingPathComponent("config/stages.json")),
            achievements: try AchievementDefinition.loadAll(from: contentRoot.appendingPathComponent("achievements.json")),
            clock: clock, calendar: calendar)
    }

    // MARK: - Events

    @discardableResult
    public func handle(_ event: GamificationEvent) throws -> GamificationEffects {
        try database.writer.write { db in try self.apply(event, db) }
    }

    /// The latest scheduler counts (due, mastered...). Used by quests, mood and achievements.
    public func updateLearning(_ snapshot: LearningSnapshot) throws {
        try database.writer.write { db in
            try Self.setMeta(db, Self.learningKey, snapshot)
            var m = try self.settle(db)
            if snapshot.masteredNotes > m.masteredHighWater {
                m.masteredHighWater = snapshot.masteredNotes
                try m.save(db)
            }
        }
    }

    /// The latest stage evidence (onboarding, placement, bands...). Stored, then re-checked on every
    /// event so time floors open on their own. Returns the effects of any stage reached now.
    @discardableResult
    public func updateStageEvidence(_ evidence: StageEvidence) throws -> GamificationEffects {
        try database.writer.write { db in
            try Self.setMeta(db, Self.evidenceKey, evidence)
            return try self.apply(nil, db)
        }
    }

    /// Settles past days and returns everything the UI shows. `context` supplies what only the app
    /// knows (asleep in quiet hours or a meeting, in a session); meters and flags come from here.
    public func state(context: MoodContext = MoodContext()) throws -> GamificationState {
        try database.writer.write { db in
            let now = self.nowMs
            let today = self.today
            let m = try self.settle(db)
            let streak = try self.streak(db, today: today)
            let todayStat = try DayStatRecord.fetchOne(db, key: today) ?? DayStatRecord(day: today)
            let quests = try QuestRecord.filter(Column("day") == today && Column("slot") != QuestSlot.weekly.rawValue).fetchAll(db)
                .sorted { QuestSlot.allCases.firstIndex(of: $0.slot)! < QuestSlot.allCases.firstIndex(of: $1.slot)! }
            let weekly = try QuestRecord.fetchOne(db, key: "\(LearningDays.weekStart(today))-weekly")
            let stats = try self.achievementStats(db, mascot: m, streak: streak)
            let unlocked = try AchievementRecord.fetchAll(db).reduce(into: [String: Int64]()) { $0[$1.id] = $1.unlockedAt }
            let contract = try self.contract(db)
            let events = try PenaltyEventRecord.fetchAll(db)
            return GamificationState(
                level: try LevelCurve.progress(totalXP: Self.totalXP(db)),
                scales: try Self.scalesBalance(db),
                mascot: m,
                stageName: self.stages.name(of: m.stage),
                mood: try self.mood(db, mascot: m, base: context),
                streak: streak,
                today: todayStat,
                quests: quests,
                weeklyQuest: weekly,
                achievements: self.achievements.map {
                    AchievementProgress(definition: $0, unlockedAt: unlocked[$0.id] ?? nil, value: AchievementEvaluator.value($0, stats))
                },
                contract: contract,
                mercyLeft: try self.mercyLeft(db, today: today),
                recoveryMode: PenaltyPolicy.Day(penaltyEvents: todayStat.penaltyEvents).recoveryMode,
                welcomeBack: streak.welcomeBack,
                catchingUp: StageEvaluator.isCatchingUp(stage: m.stage, evidence: try Self.meta(db, Self.evidenceKey) ?? StageEvidence(),
                                                        config: self.stages),
                microGrowth: try self.microGrowth(db, mascot: m, today: today),
                suggestedToDisable: PenaltyExperimentLog.suggestDisable(events, today: today)
                    .filter { PenaltyRuleKind(rawValue: $0).map { contract.isActive($0, at: now) } ?? false })
        }
    }

    // MARK: - Contract

    public func contract() throws -> Contract {
        try database.reader.read { db in try self.contract(db) }
    }

    /// Requests a rule change. Tightening takes effect at the next 04:00 boundary, loosening 24 h
    /// from now; a newer request replaces any pending one for the same rule. Returns nil (and stores
    /// nothing) for a rule that cannot be enabled (the Tivra block needs patch P1).
    @discardableResult
    public func requestRuleChange(_ kind: PenaltyRuleKind, enabled: Bool, params: String = "{}",
                                  tightens: Bool? = nil) throws -> PenaltyRuleRecord? {
        try database.writer.write { db in
            let now = self.nowMs
            let next = self.boundaryMs(ofDay: LearningDays.adding(1, to: self.today))
            guard var change = try self.contract(db).change(kind, enabled: enabled, params: params, tightens: tightens,
                                                             at: now, nextBoundary: next) else { return nil }
            try db.execute(sql: "UPDATE penalty_rule SET pendingCancelled = 1 WHERE kind = ? AND effectiveAt > ? AND pendingCancelled = 0",
                           arguments: [kind.rawValue, now])
            try change.insert(db)
            return change
        }
    }

    /// The one-click cancel on a pending change. Changes already in force cannot be cancelled.
    public func cancelPendingChange(id: Int64) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE penalty_rule SET pendingCancelled = 1 WHERE id = ? AND effectiveAt > ?",
                           arguments: [id, self.nowMs])
        }
    }

    /// Experiment log for rules other areas enforce (strict gate, forgotten word returns).
    public func logRuleOutcome(_ kind: PenaltyRuleKind, outcome: PenaltyOutcome) throws {
        try database.writer.write { db in
            var e = PenaltyEventRecord(ruleId: kind.rawValue, ts: self.nowMs, day: self.today, cost: "none", outcome: outcome)
            try e.insert(db)
        }
    }

    // MARK: - Shared helpers

    var nowMs: Int64 { Int64((clock.now.timeIntervalSince1970 * 1000).rounded()) }
    var today: Int { DayBoundary.day(for: clock.now, calendar: calendar) }

    func contract(_ db: Database) throws -> Contract {
        Contract(changes: try PenaltyRuleRecord.fetchAll(db))
    }

    func mercyLeft(_ db: Database, today: Int) throws -> Int {
        let used = try PenaltyEventRecord.filter(Column("mercyUsed") == true && Column("refunded") == false).fetchAll(db)
            .filter { LearningDays.month($0.day) == LearningDays.month(today) }.count
        return PenaltyPolicy.mercyLeft(usedThisMonth: used)
    }

    func microGrowth(_ db: Database, mascot m: MascotStateRecord, today: Int) throws -> MicroGrowth {
        let qualified = Set(try Int.fetchAll(db, sql: "SELECT day FROM day_stat WHERE qualified = 1"))
        var perWeek: [Int: Int] = [:]
        for d in qualified { perWeek[LearningDays.weekStart(d), default: 0] += 1 }
        return MicroGrowth.compute(masteredHighWater: m.masteredHighWater,
                                   qualifiedWeeks: perWeek.values.filter { $0 >= StreakEngine.weeklyGoalDays }.count,
                                   daysSinceInstall: LearningDays.distance(from: m.installedDay, to: today), config: stages)
    }

    func streak(_ db: Database, today: Int) throws -> StreakSummary {
        let days = try Int.fetchAll(db, sql: "SELECT day FROM day_stat WHERE qualified = 1")
        let paused = try Int.fetchAll(db, sql: "SELECT day FROM day_stat WHERE hatchUsed = 1 AND qualified = 0")
        return StreakEngine.summary(qualifiedDays: Set(days), today: today, unfreezableDays: Set(paused))
    }

    func mood(_ db: Database, mascot m: MascotStateRecord, base: MoodContext) throws -> MascotMood {
        var c = base
        let learning: LearningSnapshot = try Self.meta(db, Self.learningKey) ?? LearningSnapshot()
        c.vitality = m.vitality
        c.spirit = m.spirit
        c.dueCount = max(c.dueCount, learning.dueCount)
        c.oldestOverdueHours = max(c.oldestOverdueHours, learning.oldestOverdueHours)
        c.repairInProgress = c.repairInProgress || m.repairActive
        c.justHealed = c.justHealed || (m.healedAt.map { nowMs - $0 < Self.justHealedWindowMs } ?? false)
        return MoodResolver.mood(c)
    }

    static func totalXP(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(amount), 0) FROM xp_event") ?? 0
    }

    static func scalesBalance(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(amount), 0) FROM scales_event") ?? 0
    }

    static func meta<T: Decodable>(_ db: Database, _ key: String) throws -> T? {
        guard let s = try String.fetchOne(db, sql: "SELECT value FROM app_meta WHERE key = ?", arguments: [key]) else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(s.utf8))
    }

    static func setMeta<T: Encodable>(_ db: Database, _ key: String, _ value: T) throws {
        let s = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        try db.execute(sql: "INSERT INTO app_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                       arguments: [key, s])
    }
}
