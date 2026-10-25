import Foundation
@testable import TenazCore

/// An engine on an in-memory database with the bundled stages and achievements, a manual clock
/// starting Monday 2 Nov 2026 10:00 in Mexico City (no DST) and a calendar fixed to that zone.
struct GamificationFixture {
    static let timeZone = TimeZone(identifier: "America/Mexico_City")!
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    let clock: TestClock
    let engine: GamificationEngine

    init(hour: Int = 10) throws {
        let start = Self.calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: hour))!
        clock = TestClock(start)
        engine = try GamificationEngine.bundled(database: .inMemory(), contentRoot: ContentTests.contentRoot,
                                                clock: clock, calendar: Self.calendar)
    }

    var today: Int { DayBoundary.day(for: clock.now, calendar: Self.calendar) }

    func advance(days: Int) { clock.advance(by: Double(days) * 86400) }
    func advance(hours: Double) { clock.advance(by: hours * 3600) }

    /// Turns a rule on and moves to the next day, when the tightening takes effect.
    func arm(_ kinds: PenaltyRuleKind...) throws {
        for k in kinds { try engine.requestRuleChange(k, enabled: true) }
        advance(days: 1)
    }

    @discardableResult
    func review(_ id: String = "card", correct: Bool = true, difficulty: Double = 5) throws -> GamificationEffects {
        try engine.handle(.reviewAnswered(AnsweredReview(cardId: id, correct: correct, difficulty: difficulty)))
    }

    /// The minimum viable day: 10 correct retrievals (distinct cards) + 1 production.
    func qualifyToday() throws {
        for i in 0..<10 { try review("c\(i)") }
        try engine.handle(.productionDone(Production(refId: "p\(today)", quality: 0.6, words: 20)))
    }

    var state: GamificationState { get throws { try engine.state() } }
}
