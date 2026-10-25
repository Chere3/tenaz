import Foundation
import Testing
@testable import TenazCore

struct PromotionTests {
    static let day: TimeInterval = 86_400
    static let start = Date(timeIntervalSince1970: 1_792_000_000)

    static func monthly(_ id: String, day: Double, theta: Double = 0.4, sd: Double = 0.15, verified: Bool = true,
                        weakest: Double = 4.0) -> MonthlyEvidence {
        var bands = Dictionary(uniqueKeysWithValues: ExamSkill.sections.map { ($0, 4.5) })
        bands[.speaking] = weakest
        return MonthlyEvidence(attemptId: id, endedAt: start + day * Self.day, overallMean: theta, overallSD: sd,
                               sectionBands: bands, verified: verified)
    }

    static let weekly = WeeklyEvidence(attemptId: "w", endedAt: start + 40 * day, overallMean: 0.3)

    @Test func needsTwoVerifiedMonthlies() {
        let one = PromotionRules.evaluate(current: 3.5, monthlies: [Self.monthly("m1", day: 28)], weeklies: [Self.weekly],
                                          anchorDriftOK: true)
        #expect(one != .promote(from: 3.5, to: 4.0))

        let unverified = PromotionRules.evaluate(
            current: 3.5, monthlies: [Self.monthly("m1", day: 28), Self.monthly("m2", day: 56, verified: false)],
            weeklies: [Self.weekly], anchorDriftOK: true)
        #expect(unverified != .promote(from: 3.5, to: 4.0))

        let both = PromotionRules.evaluate(
            current: 3.5, monthlies: [Self.monthly("m1", day: 28), Self.monthly("m2", day: 56)],
            weeklies: [Self.weekly], anchorDriftOK: true)
        #expect(both == .promote(from: 3.5, to: 4.0))
    }

    @Test func holdsWhenAnyOtherRuleFails() {
        let pair = [Self.monthly("m1", day: 28), Self.monthly("m2", day: 56)]
        // Not confident enough: P(theta > 0) < 0.8.
        let unsure = [Self.monthly("m1", day: 28, theta: 0.05, sd: 0.4), Self.monthly("m2", day: 56)]
        #expect(PromotionRules.evaluate(current: 3.5, monthlies: unsure, weeklies: [Self.weekly], anchorDriftOK: true) != .promote(from: 3.5, to: 4.0))
        // One skill more than a band below the target.
        let weak = [Self.monthly("m1", day: 28), Self.monthly("m2", day: 56, weakest: 2.5)]
        #expect(PromotionRules.evaluate(current: 3.5, monthlies: weak, weeklies: [Self.weekly], anchorDriftOK: true) != .promote(from: 3.5, to: 4.0))
        // Anchor drift.
        #expect(PromotionRules.evaluate(current: 3.5, monthlies: pair, weeklies: [Self.weekly], anchorDriftOK: false) != .promote(from: 3.5, to: 4.0))
        // No agreeing weekly between the monthlies.
        let farWeekly = WeeklyEvidence(attemptId: "w", endedAt: Self.start + 40 * Self.day, overallMean: -0.5)
        #expect(PromotionRules.evaluate(current: 3.5, monthlies: pair, weeklies: [farWeekly], anchorDriftOK: true) != .promote(from: 3.5, to: 4.0))
    }

    @Test func neverDemotes() throws {
        // Evidence far below the current band only holds.
        let bad = [Self.monthly("m1", day: 28, theta: -2), Self.monthly("m2", day: 56, theta: -2)]
        guard case .hold = PromotionRules.evaluate(current: 4.0, monthlies: bad, weeklies: [], anchorDriftOK: true) else {
            Issue.record("expected hold")
            return
        }

        // In the store, the public band is the maximum ever granted.
        let store = ExamStore(database: try TenazDatabase.inMemory())
        try store.database.writer.write { db in
            for (i, band) in [4.0, 3.0].enumerated() {
                var row = BandHistoryRecord(id: nil, ts: Int64(i), day: 20261022, attemptId: nil, kind: "promotion",
                                            skill: BandHistoryRecord.publicBand, band: band, low: band, high: band,
                                            thetaMean: 0, sd: 0, verified: true)
                try row.insert(db)
            }
        }
        #expect(try store.publicBand() == 4.0)
        #expect(try store.evaluatePromotion(anchorDriftOK: true, at: Date()) != .promote(from: 4.0, to: 4.5))
        #expect(try store.publicBand() == 4.0)
    }

    /// Stores one finished monthly section attempt with band rows for `skills` and an overall row.
    static func storeSection(_ store: ExamStore, id: String, group: String, startHour: Double, hours: Double,
                             skills: [ExamSkill], integrity: IntegrityLevel = .clean) throws {
        let begin = Int64((Self.start.timeIntervalSince1970 + startHour * 3600) * 1000)
        let end = begin + Int64(hours * 3600 * 1000)
        try store.database.writer.write { db in
            try ExamAttemptRecord(id: id, kind: "monthly", blueprintId: "monthly-v1", seed: 1, startedAt: begin, endedAt: end,
                                  status: "done", integrity: integrity.rawValue, integrityConfirmed: false, integrityJSON: nil,
                                  pausedMs: 0, routes: nil, mockGroupId: group, priors: nil, excluded: nil).insert(db)
            for skill in skills.map(\.rawValue) + [BandHistoryRecord.overall] {
                var row = BandHistoryRecord(id: nil, ts: end, day: 20261101, attemptId: id, kind: "monthly", skill: skill,
                                            band: 4.5, low: 4.0, high: 5.0, thetaMean: 0.5, sd: 0.15, verified: true)
                try row.insert(db)
            }
        }
    }

    @Test func sectionedMockWithin72h() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        // Group A: four sections over 50 hours, all clean → one verified mock.
        try Self.storeSection(store, id: "a1", group: "A", startHour: 0, hours: 0.5, skills: [.reading])
        try Self.storeSection(store, id: "a2", group: "A", startHour: 20, hours: 0.5, skills: [.listening])
        try Self.storeSection(store, id: "a3", group: "A", startHour: 49, hours: 1, skills: [.writing, .speaking])
        // Group B: last section 80 hours after the first → outside the window.
        try Self.storeSection(store, id: "b1", group: "B", startHour: 600, hours: 1, skills: [.reading, .listening])
        try Self.storeSection(store, id: "b2", group: "B", startHour: 680, hours: 1, skills: [.writing, .speaking])
        // Group C: complete and on time, but one section is a VIOLATION.
        try Self.storeSection(store, id: "c1", group: "C", startHour: 1200, hours: 1, skills: [.reading, .listening])
        try Self.storeSection(store, id: "c2", group: "C", startHour: 1210, hours: 1, skills: [.writing, .speaking], integrity: .violation)
        // Group D: on time and clean, but no speaking section.
        try Self.storeSection(store, id: "d1", group: "D", startHour: 1800, hours: 1, skills: [.reading, .listening, .writing])

        let monthlies = try store.promotionEvidence().monthlies
        #expect(monthlies.map(\.attemptId) == ["a3", "b2", "c2", "d1"])
        #expect(monthlies.map(\.verified) == [true, false, false, false])
        #expect(monthlies.first?.sectionBands.count == 4)
    }

    @Test func promotionEvidenceIsNotReused() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        try Self.storeSection(store, id: "m1", group: "m1", startHour: 0, hours: 2, skills: ExamSkill.sections)
        try Self.storeSection(store, id: "m2", group: "m2", startHour: 700, hours: 2, skills: ExamSkill.sections)
        let weeklyEnd = Int64((Self.start.timeIntervalSince1970 + 350 * 3600) * 1000)
        try store.database.writer.write { db in
            try ExamAttemptRecord(id: "w1", kind: "weekly", blueprintId: "weekly-v1", seed: 1, startedAt: weeklyEnd - 1000, endedAt: weeklyEnd,
                                  status: "done", integrity: nil, integrityConfirmed: false, integrityJSON: nil,
                                  pausedMs: 0, routes: nil, mockGroupId: nil, priors: nil, excluded: nil).insert(db)
            var overall = BandHistoryRecord(id: nil, ts: weeklyEnd, day: 20261101, attemptId: "w1", kind: "weekly", skill: BandHistoryRecord.overall,
                                            band: 4.5, low: 4.0, high: 5.0, thetaMean: 0.5, sd: 0.15, verified: false)
            try overall.insert(db)
            var pub = BandHistoryRecord(id: nil, ts: 1, day: 20261001, attemptId: nil, kind: "placement", skill: BandHistoryRecord.publicBand,
                                        band: 3.5, low: 3.5, high: 3.5, thetaMean: 0, sd: 0, verified: true)
            try pub.insert(db)
        }
        let first = try store.evaluatePromotion(anchorDriftOK: true, at: Self.start + 800 * 3600)
        #expect(first == .promote(from: 3.5, to: 4.0))
        // The same two monthlies cannot also earn the next step.
        let second = try store.evaluatePromotion(anchorDriftOK: true, at: Self.start + 801 * 3600)
        #expect(second != .promote(from: 4.0, to: 4.5))
        #expect(try store.publicBand() == 4.0)
    }
}
