import Foundation
import GRDB

extension GamificationEngine {
    /// Closes every learning day that ended since the last call and prepares today. Idempotent.
    @discardableResult
    func settle(_ db: Database) throws -> MascotStateRecord {
        let now = nowMs
        let today = self.today
        let yesterday = LearningDays.adding(-1, to: today)
        var m: MascotStateRecord
        if let existing = try MascotStateRecord.fetchOne(db, key: 1) {
            m = existing
        } else {
            m = MascotStateRecord(now: now, today: today, yesterday: yesterday)
            try m.insert(db)
        }
        let contract = try self.contract(db)
        var todayStat = try DayStatRecord.fetchOne(db, key: today) ?? DayStatRecord(day: today)

        if m.lastSettledDay < yesterday {
            m.combo = 0
            var missedAny = false
            for day in LearningDays.range(LearningDays.adding(1, to: m.lastSettledDay), through: yesterday) {
                var stat = try DayStatRecord.fetchOne(db, key: day) ?? DayStatRecord(day: day)
                var vitality = 0
                var spirit = 0
                if !stat.qualified {
                    missedAny = true
                    // Only under Response cost, judged as of that day's end; soft freeze after 2 in a row.
                    let dayEnd = boundaryMs(ofDay: LearningDays.adding(1, to: day)) - 1
                    let missedRun = try missedRunEnding(db, at: day, installedDay: m.installedDay)
                    if contract.isActive(.responseCost, at: dayEnd), missedRun <= PenaltyPolicy.softFreezeAfterMissedDays {
                        let d = PenaltyPolicy.price(.missedMinimum, day: PenaltyPolicy.Day(vitalityLost: stat.vitalityLost, penaltyEvents: stat.penaltyEvents),
                                                    ruleActive: true)
                        vitality = MascotMeters.clampVitality(m.vitality + d.vitality) - m.vitality
                        stat.vitalityLost += -vitality
                        let scales = ScalesRules.clampedChange(d.scales, balance: try Self.scalesBalance(db))
                        if scales != 0 {
                            var s = ScalesEventRecord(ts: now, amount: scales, source: "penalty.missedMinimum", refId: String(day))
                            try s.insert(db)
                        }
                        if d.countsAsEvent { stat.penaltyEvents += 1 }
                        var e = PenaltyEventRecord(ruleId: PenaltyRuleKind.responseCost.rawValue, ts: now, day: day,
                                                   cost: PenaltyCost.missedMinimum.rawValue, outcome: d.outcome)
                        e.vitality = vitality
                        e.scales = scales
                        try e.insert(db)
                    }
                }
                if !stat.hadSession { spirit = MascotMeters.clampSpirit(m.spirit + MascotMeters.dailyDecayWithoutSession) - m.spirit }
                m.vitality += vitality
                m.spirit += spirit
                if vitality != 0 || spirit != 0 {
                    var e = MascotEventRecord(ts: now, kind: "day.\(day)", vitalityDelta: vitality, spiritDelta: spirit)
                    try e.insert(db)
                }
                stat.closed = true
                try stat.save(db)
            }
            // Extra cards (opt-in): one +5 set today after any missed day, inside the task budget.
            let streakNow = try streak(db, today: today)
            if missedAny, contract.isActive(.extraCards, at: now),
               PenaltyPolicy.taskFits(minutes: 1, day: PenaltyPolicy.Day(penaltyEvents: todayStat.penaltyEvents, taskMinutes: todayStat.penaltyTaskMinutes,
                                                                          welcomeBack: streakNow.welcomeBack)) {
                todayStat.penaltyTaskMinutes += 1
                var e = PenaltyEventRecord(ruleId: PenaltyRuleKind.extraCards.rawValue, ts: now, day: today, cost: "none", outcome: .fired)
                e.task = "extraCards:5"
                try e.insert(db)
            }
            try db.execute(sql: "UPDATE day_stat SET frozen = 0 WHERE frozen = 1")
            for day in streakNow.frozenDays {
                var stat = try DayStatRecord.fetchOne(db, key: day) ?? DayStatRecord(day: day)
                stat.frozen = true
                stat.closed = true
                try stat.save(db)
            }
            m.lastSettledDay = yesterday
            // Welcome back (3+ missed days): penalties are paused today, and under Response cost
            // Tena gets +10 Vitality once.
            if streakNow.welcomeBack, m.lastWelcomeBackDay != today {
                m.lastWelcomeBackDay = today
                if contract.isActive(.responseCost, at: now) {
                    let gain = MascotMeters.clampVitality(m.vitality + PenaltyPolicy.welcomeBackVitality) - m.vitality
                    m.vitality += gain
                    var e = MascotEventRecord(ts: now, kind: "welcomeBack", vitalityDelta: gain, spiritDelta: 0)
                    try e.insert(db)
                }
            }
            try startRepairIfNeeded(db, mascot: &m, stat: &todayStat, contract: contract)
            try todayStat.save(db)
        }

        try generateQuests(db, mascot: &m, today: today)
        try m.save(db)
        return m
    }

    /// Consecutive missed (unqualified) days ending at `day`, not counting days before install.
    func missedRunEnding(_ db: Database, at day: Int, installedDay: Int) throws -> Int {
        var run = 0
        var d = day
        while d >= installedDay, run <= PenaltyPolicy.softFreezeAfterMissedDays {
            if try DayStatRecord.fetchOne(db, key: d)?.qualified == true { break }
            run += 1
            d = LearningDays.adding(-1, to: d)
        }
        return run
    }

    /// Unix ms of 04:00 local time on `day` (the start of that learning day).
    func boundaryMs(ofDay day: Int) -> Int64 {
        let c = DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100, hour: DayBoundary.hour)
        let date = calendar.date(from: c) ?? clock.now
        return Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    /// Today's three quests and this week's quest, once each, with adaptive targets.
    func generateQuests(_ db: Database, mascot m: inout MascotStateRecord, today: Int) throws {
        let hasDaily = try QuestRecord.filter(Column("day") == today && Column("slot") == QuestSlot.core.rawValue).fetchCount(db) > 0
        if !hasDaily {
            let from = LearningDays.adding(-7, to: today)
            let recent = try QuestRecord.filter(Column("day") >= from && Column("day") < today).fetchAll(db)
                .filter { $0.slot == .skill || $0.slot == .stretch }
            m.questMultiplier = QuestTuning.nextMultiplier(m.questMultiplier, done: recent.filter(\.done).count, total: recent.count)
            let learning: LearningSnapshot = try Self.meta(db, Self.learningKey) ?? LearningSnapshot()
            for q in QuestGenerator.daily(day: today, dueCount: learning.dueCount, weakestCategory: learning.weakestCategory,
                                          multiplier: m.questMultiplier) {
                try q.insert(db)
            }
        }
        let week = LearningDays.weekStart(today)
        if try QuestRecord.fetchOne(db, key: "\(week)-weekly") == nil {
            try QuestGenerator.weekly(weekStart: week).insert(db)
        }
    }
}
