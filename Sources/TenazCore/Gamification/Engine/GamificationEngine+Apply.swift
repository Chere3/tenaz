import Foundation
import GRDB

extension GamificationEngine {
    /// Applies one event (or nil: only re-check stages and achievements) inside a transaction.
    func apply(_ event: GamificationEvent?, _ db: Database) throws -> GamificationEffects {
        let now = nowMs
        let today = self.today
        var m = try settle(db)
        var stat = try DayStatRecord.fetchOne(db, key: today) ?? DayStatRecord(day: today)
        let streakBefore = try streak(db, today: today)
        let xpBefore = try Self.totalXP(db)
        let levelBefore = LevelCurve.progress(totalXP: xpBefore)
        let stageBefore = m.stage
        let wasQualified = stat.qualified
        let dayIndex = LearningDays.distance(from: m.installedDay, to: today)
        let contract = try self.contract(db)
        var fx = GamificationEffects(level: levelBefore)
        var vitality = 0
        var spirit = 0
        var xpGrants: [(amount: Int, source: String, refId: String?)] = []
        var questBumps: [QuestMetric: Int] = [:]
        var session = false
        var celebrating = false
        var discovering = false

        func dayPolicy() -> PenaltyPolicy.Day {
            PenaltyPolicy.Day(vitalityLost: stat.vitalityLost, penaltyEvents: stat.penaltyEvents,
                              taskMinutes: stat.penaltyTaskMinutes, welcomeBack: streakBefore.welcomeBack)
        }

        func charge(_ cost: PenaltyCost, wantsMercy: Bool = false, escaped: Bool = false) throws {
            let rule = cost.rule
            guard contract.isActive(rule, at: now) else { return }
            let d = PenaltyPolicy.price(cost, day: dayPolicy(), ruleActive: true, wantsMercy: wantsMercy,
                                        mercyLeft: try mercyLeft(db, today: today), escaped: escaped)
            let applied = MascotMeters.clampVitality(m.vitality + vitality + d.vitality) - (m.vitality + vitality)
            vitality += applied
            stat.vitalityLost += -applied
            let scales = ScalesRules.clampedChange(d.scales, balance: try Self.scalesBalance(db))
            if scales != 0 {
                var s = ScalesEventRecord(ts: now, amount: scales, source: "penalty.\(cost.rawValue)")
                try s.insert(db)
            }
            if d.countsAsEvent { stat.penaltyEvents += 1 }
            var e = PenaltyEventRecord(ruleId: rule.rawValue, ts: now, day: today, cost: cost.rawValue, outcome: d.outcome)
            e.vitality = applied
            e.scales = scales
            e.mercyUsed = d.mercyUsed
            if cost == .examStake, d.countsAsEvent { e.task = "retakeBy:\(now + 48 * 3600 * 1000)" }
            try e.insert(db)
            fx.scales += scales
            fx.penalty = AppliedPenalty(eventId: e.id, cost: cost, vitality: applied, scales: scales, mercyUsed: d.mercyUsed,
                                        outcome: d.outcome, ruleChosenAt: contract.inForce(rule, at: now)?.createdAt)
        }

        /// Gives a penalty back in full (Vitality, Scales, the event count) and marks it refunded.
        func refund(_ id: Int64) throws {
            guard var e = try PenaltyEventRecord.fetchOne(db, key: id), !e.refunded else { return }
            let back = MascotMeters.clampVitality(m.vitality + vitality - e.vitality) - (m.vitality + vitality)
            vitality += back
            if e.scales != 0 {
                var s = ScalesEventRecord(ts: now, amount: -e.scales, source: "refund", refId: String(id))
                try s.insert(db)
                fx.scales -= e.scales
            }
            if e.day == today {
                stat.vitalityLost = max(0, stat.vitalityLost + e.vitality)
                if e.outcome != .waived { stat.penaltyEvents = max(0, stat.penaltyEvents - 1) }
            }
            e.refunded = true
            try e.update(db)
        }

        func touch() {
            if stat.firstActivityAt == nil { stat.firstActivityAt = now }
            session = true
        }

        func produce(_ p: Production, source: String) throws {
            touch()
            stat.productions += 1
            spirit += MascotMeters.writing
            let prior = try Int.fetchOne(db, sql: "SELECT count(*) FROM xp_event WHERE day = ? AND refId = ?",
                                         arguments: [today, p.refId]) ?? 0
            let xp = XPRules.welcomeBonus(XPRules.antiFarming(XPRules.production(quality: p.quality), priorToday: prior), dayIndex: dayIndex)
            xpGrants.append((xp, source, p.refId))
            questBumps[.productions, default: 0] += 1
            if p.kind == .spokenSummary { questBumps[.spokenSummaries, default: 0] += 1 }
            let kind = source == "gate" ? "writing.gate" : (p.words >= Production.paragraphWords ? "writing.paragraph" : "writing.\(p.kind.rawValue)")
            var e = MascotEventRecord(ts: now, kind: kind, vitalityDelta: 0, spiritDelta: 0)
            try e.insert(db)
            if m.repairActive, p.words >= RepairTask.paragraphWords { m.repairParagraphDone = true }
            if let text = p.text, text.lowercased().contains("my fly"), !m.flyMentioned {
                m.flyMentioned = true
                discovering = true
            }
        }

        switch event {
        case nil:
            break
        case let .reviewAnswered(a):
            touch()
            stat.reviewsDone += 1
            if calendar.component(.hour, from: clock.now) < DayBoundary.hour { stat.nightReviews += 1 }
            questBumps[.reviewsDone, default: 0] += 1
            if a.correct {
                stat.correctRetrievals += 1
                m.combo += 1
                m.bestCombo = max(m.bestCombo, m.combo)
                spirit += MascotMeters.correctRecall
                let prior = try Int.fetchOne(db, sql: "SELECT count(*) FROM xp_event WHERE day = ? AND refId = ?",
                                             arguments: [today, a.cardId]) ?? 0
                let base = a.correctedAfterFail ? XPRules.correctedAfterFail : XPRules.review(difficulty: a.difficulty)
                xpGrants.append((XPRules.welcomeBonus(XPRules.antiFarming(base, priorToday: prior), dayIndex: dayIndex), "review", a.cardId))
                if m.repairActive, !a.usedHint { m.repairReviews += 1 }
            } else {
                m.combo = 0
                spirit += MascotMeters.wrongRecall
            }
            let regain = MascotMeters.regain(reviewsDone: stat.reviewsDone, regainedToday: stat.vitalityRegained, lostToday: stat.vitalityLost,
                                              vitality: m.vitality + vitality)
            let applied = MascotMeters.clampVitality(m.vitality + vitality + regain) - (m.vitality + vitality)
            vitality += applied
            stat.vitalityRegained += applied
        case let .productionDone(p):
            try produce(p, source: "production")
        case let .gateCompleted(p):
            try produce(p, source: "gate")
        case let .gateSkipped(useMercy):
            try charge(.gateSkip, wantsMercy: useMercy, escaped: true)
        case let .gateTimedOut(abandoned):
            if abandoned { try charge(.gateTimeoutAbandoned) }
        case .overlaySkipped:
            try charge(.overlaySkip, escaped: true)
        case let .meetingClaimUncorroborated(workCalendarVisible):
            stat.meetingClaims += 1
            if stat.meetingClaims > PenaltyPolicy.freeMeetingClaimsPerDay, workCalendarVisible {
                try charge(.meetingClaimUncorroborated, escaped: true)
            }
        case let .penaltyRefunded(id):
            try refund(id)
        case .intrusionsPaused:
            stat.hatchUsed = true
        case let .examFinished(o):
            var r = ExamOutcomeRecord(ts: now, outcome: o)
            try r.insert(db)
            if o.integrity.isVerified {
                let sections = o.sectionBands.isEmpty ? [o.band] : o.sectionBands
                let xp = sections.map(XPRules.examSection).reduce(0, +)
                xpGrants.append((XPRules.welcomeBonus(xp, dayIndex: dayIndex), "exam.\(o.kind.rawValue)", o.attemptId))
                stat.correctRetrievals += o.correctItems
                stat.productions += o.productions
                if o.correctItems + o.productions > 0, stat.firstActivityAt == nil { stat.firstActivityAt = now }
            }
            let mock = o.kind == .weeklyMock || o.kind == .monthlyMock
            if mock, o.failed || o.integrity == .violation { try charge(.examStake) }
        }

        if case .reviewAnswered = event { questBumps[.comboToday] = m.combo }

        // Repair task: start it when Tena is sick, finish it when both parts are done.
        m.vitality = MascotMeters.clampVitality(m.vitality + vitality)
        m.spirit = MascotMeters.clampSpirit(m.spirit + spirit)
        if m.repairActive, RepairTask.isComplete(reviews: m.repairReviews, paragraphDone: m.repairParagraphDone) {
            let before = m.vitality
            m.vitality = max(m.vitality, MascotMeters.healedVitality)
            vitality += m.vitality - before
            m.repairActive = false
            m.healedAt = now
            fx.repairCompleted = true
            try db.execute(sql: "UPDATE penalty_event SET cleared = 1, clearedAt = ? WHERE task = 'repair' AND cleared = 0", arguments: [now])
            var e = MascotEventRecord(ts: now, kind: "healed", vitalityDelta: 0, spiritDelta: 0)
            try e.insert(db)
        }
        try startRepairIfNeeded(db, mascot: &m, stat: &stat, contract: contract)
        if m.repairActive { fx.repairLimbs = RepairTask.limbsRegrown(reviews: m.repairReviews, paragraphDone: m.repairParagraphDone) }

        if vitality != 0 || spirit != 0, let event {
            var e = MascotEventRecord(ts: now, kind: Self.kind(of: event), vitalityDelta: vitality, spiritDelta: spirit)
            try e.insert(db)
        }

        // An escape hatch used just before a session counts as "led to a session" in the log.
        if session {
            try db.execute(sql: "UPDATE penalty_event SET ledToSession = 1 WHERE ts >= ? AND outcome != 'waived'",
                           arguments: [now - Self.ledToSessionWindowMs])
        }

        stat.qualified = StreakEngine.qualifies(correctRetrievals: stat.correctRetrievals, productions: stat.productions)
        fx.dayQualified = stat.qualified && !wasQualified
        try stat.save(db)

        // Quests.
        for var q in try QuestRecord.filter(Column("day") == today || Column("day") == LearningDays.weekStart(today)).fetchAll(db) where !q.done {
            guard let bump = questBumps[q.metric] else { continue }
            if q.slot != .weekly, q.day != today { continue }
            q.progress = q.metric == .comboToday ? max(q.progress, bump) : q.progress + bump
            if q.progress >= q.target {
                q.done = true
                fx.questsCompleted.append(q)
                xpGrants.append((XPRules.quest(q.rewardXP), "quest", q.id))
                var s = ScalesEventRecord(ts: now, amount: q.rewardScales, source: "quest", refId: q.id)
                try s.insert(db)
                fx.scales += q.rewardScales
                celebrating = true
            }
            try q.save(db)
            fx.questProgress.append(q)
        }

        // Stage (re-checked on every call so time floors open by themselves).
        let evidence: StageEvidence = try Self.meta(db, Self.evidenceKey) ?? StageEvidence()
        while m.stage < stages.maxStage {
            let e = try filledEvidence(db, evidence, mascot: m, today: today)
            let next = StageEvaluator.nextStage(current: m.stage, evidence: e, config: stages)
            guard next > m.stage else { break }
            m.stage = next
            m.stageSince = now
            var ev = MascotEventRecord(ts: now, kind: "stage.\(next)", vitalityDelta: 0, spiritDelta: 0)
            try ev.insert(db)
        }
        fx.stage = m.stage
        fx.stageAdvanced = m.stage > stageBefore
        if fx.stageAdvanced { celebrating = true }

        for g in xpGrants where g.amount > 0 {
            var x = XPEventRecord(ts: now, day: today, amount: g.amount, source: g.source, refId: g.refId)
            try x.insert(db)
        }
        try m.save(db)

        // Achievements (they may grant XP, which is added after).
        let streakAfter = try streak(db, today: today)
        let stats = try achievementStats(db, mascot: m, streak: streakAfter)
        let already = Set(try String.fetchAll(db, sql: "SELECT id FROM achievement WHERE unlockedAt IS NOT NULL"))
        for def in AchievementEvaluator.newlyUnlocked(achievements, stats: stats, alreadyUnlocked: already) {
            try AchievementRecord(id: def.id, unlockedAt: now, progress: AchievementEvaluator.value(def, stats) ?? def.threshold).save(db)
            if def.reward.xp > 0 {
                var x = XPEventRecord(ts: now, day: today, amount: def.reward.xp, source: "achievement", refId: def.id)
                try x.insert(db)
            }
            if def.reward.scales > 0 {
                var s = ScalesEventRecord(ts: now, amount: def.reward.scales, source: "achievement", refId: def.id)
                try s.insert(db)
                fx.scales += def.reward.scales
            }
            fx.unlocked.append(def)
            celebrating = true
        }

        let xpAfter = try Self.totalXP(db)
        let earned = ScalesRules.earned(totalXPBefore: xpBefore, after: xpAfter)
        if earned > 0 {
            var s = ScalesEventRecord(ts: now, amount: earned, source: "xp")
            try s.insert(db)
            fx.scales += earned
        }
        fx.xp = xpAfter - xpBefore
        fx.level = LevelCurve.progress(totalXP: xpAfter)
        fx.leveledUp = fx.level.level > levelBefore.level
        if fx.leveledUp { celebrating = true }
        fx.vitalityDelta = vitality
        fx.spiritDelta = spirit
        fx.streak = streakAfter
        fx.welcomeBack = streakBefore.welcomeBack
        fx.recoveryMode = PenaltyPolicy.Day(penaltyEvents: stat.penaltyEvents).recoveryMode
        fx.mood = try mood(db, mascot: m, base: MoodContext(inSession: session, celebrating: celebrating, discovering: discovering))
        return fx
    }

    /// The stored evidence plus what the engine knows: total reviews, the time floors, the mastered
    /// high-water mark and the public band (read here so placement and promotions count without each
    /// caller merging them). The floor counts the day the current stage was reached, so stage 3 can open on day 1.
    func filledEvidence(_ db: Database, _ evidence: StageEvidence, mascot m: MascotStateRecord, today: Int) throws -> StageEvidence {
        var e = evidence
        e.masteredNotes = max(e.masteredNotes, m.masteredHighWater)
        if let band = try ExamStore.publicBand(db) { e.publicBand = max(e.publicBand ?? band, band) }
        let since = DayBoundary.day(for: Date(timeIntervalSince1970: Double(m.stageSince) / 1000), calendar: calendar)
        e.reviewsDone = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(reviewsDone), 0) FROM day_stat") ?? 0
        e.qualifiedDaysSinceStage = try Int.fetchOne(db, sql: "SELECT count(*) FROM day_stat WHERE qualified = 1 AND day >= ?",
                                                     arguments: [since]) ?? 0
        e.daysSinceStage = LearningDays.distance(from: since, to: today)
        return e
    }

    /// At Sick, with the repair rule in force and room in today's 5-minute task budget.
    func startRepairIfNeeded(_ db: Database, mascot m: inout MascotStateRecord, stat: inout DayStatRecord, contract: Contract) throws {
        guard !m.repairActive, MascotMeters.isSick(vitality: m.vitality), contract.isActive(.repairTask, at: nowMs) else { return }
        let welcomeBack = try streak(db, today: stat.day).welcomeBack
        let day = PenaltyPolicy.Day(vitalityLost: stat.vitalityLost, penaltyEvents: stat.penaltyEvents,
                                    taskMinutes: stat.penaltyTaskMinutes, welcomeBack: welcomeBack)
        guard PenaltyPolicy.taskFits(minutes: RepairTask.estimatedMinutes, day: day) else { return }
        m.repairActive = true
        m.repairReviews = 0
        m.repairParagraphDone = false
        stat.penaltyTaskMinutes += RepairTask.estimatedMinutes
        var e = PenaltyEventRecord(ruleId: PenaltyRuleKind.repairTask.rawValue, ts: nowMs, day: stat.day, cost: "none", outcome: .fired)
        e.task = "repair"
        try e.insert(db)
    }

    static func kind(of event: GamificationEvent) -> String {
        switch event {
        case let .reviewAnswered(a): a.correct ? "review.correct" : "review.wrong"
        case .productionDone: "production"
        case .gateCompleted: "gate.completed"
        case .gateSkipped: "gate.skipped"
        case .gateTimedOut: "gate.timeout"
        case .overlaySkipped: "overlay.skipped"
        case .meetingClaimUncorroborated: "hatch.meetingClaim"
        case .penaltyRefunded: "penalty.refunded"
        case .intrusionsPaused: "hatch.paused"
        case .examFinished: "exam"
        }
    }
}
