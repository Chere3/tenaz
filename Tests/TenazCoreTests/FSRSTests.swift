import Foundation
import Testing
@testable import TenazCore

/// Golden vectors from py-fsrs 6.3.2 (default parameters, retention 0.90, no learning steps, no fuzz),
/// copied from fluo's FsrsSchedulerTest and re-verified there against py-fsrs.
struct FSRSTests {
    let fsrs = FSRS()
    let start = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!

    func close(_ expected: Double, _ actual: Double) -> Bool {
        abs(expected - actual) <= max(0.02, abs(expected) * 0.01)
    }

    @Test func goldenVectorsMatchPyFSRS() {
        let golden: [(Rating, Double, Double, Int)] = [
            (.good, 2.306500, 2.118104, 2),
            (.hard, 7.513320, 4.752858, 8),
            (.good, 26.407944, 4.743334, 26),
            (.again, 2.202716, 8.257398, 2),
            (.good, 4.863953, 8.244369, 5),
            (.easy, 15.461535, 7.642947, 15),
        ]
        var card = MemoryState()
        var t = start
        for (i, g) in golden.enumerated() {
            card = fsrs.review(card, rating: g.0, at: t).card
            let interval = Int((card.due!.timeIntervalSince(t) / 86400).rounded())
            #expect(close(g.1, card.stability!), "step \(i) stability \(card.stability!)")
            #expect(close(g.2, card.difficulty!), "step \(i) difficulty \(card.difficulty!)")
            #expect(interval == g.3, "step \(i) interval")
            t = card.due!
        }
    }

    @Test func newCardIntervalsAreOrdered() {
        let iv = fsrs.previewIntervals(MemoryState(), at: start)
        #expect(iv[.easy]! >= iv[.good]!)
        #expect(iv[.good]! >= iv[.hard]!)
        #expect(iv[.hard]! >= iv[.again]!)
    }

    @Test func againOnReviewCardCountsALapse() {
        var card = fsrs.review(MemoryState(), rating: .good, at: start).card
        #expect(card.lapses == 0)
        card = fsrs.review(card, rating: .again, at: card.due!).card
        #expect(card.lapses == 1)
        #expect(card.state == .relearning)
    }

    @Test func retrievabilityDecays() {
        let card = fsrs.review(MemoryState(), rating: .good, at: start).card
        let r1 = fsrs.retrievability(card, elapsedDays: 1)
        let r10 = fsrs.retrievability(card, elapsedDays: 10)
        #expect(r1 > r10)
        #expect(close(0.9, fsrs.retrievability(card, elapsedDays: card.stability!)))
    }

    @Test func difficultyStaysInBounds() {
        var card = MemoryState()
        var t = start
        for _ in 0..<20 {
            card = fsrs.review(card, rating: .again, at: t).card
            t = card.due!
            #expect((1...10).contains(card.difficulty!))
        }
    }
}

/// Learning steps and py-fsrs parity (fixtures from `scripts/fsrs-fixtures.py`).
extension FSRSTests {
    func replay(_ seq: FSRSFixture.Sequence) {
        let scheduler = seq.scheduler
        var card = MemoryState()
        for (i, g) in seq.reviews.enumerated() {
            let at = Date(timeIntervalSince1970: g.at)
            card = scheduler.review(card, rating: Rating(rawValue: g.rating)!, at: at)
            let label = "\(seq.name) step \(i)"
            let state: String = switch card.state { case .learning: "learning"; case .review: "review"; case .relearning: "relearning" }
            #expect(state == g.state, "\(label) state")
            #expect(card.step == g.step, "\(label) step")
            #expect(abs(card.stability! - g.stability) <= 1e-9 * max(1, g.stability), "\(label) S \(card.stability!) vs \(g.stability)")
            #expect(abs(card.difficulty! - g.difficulty) <= 1e-9 * max(1, g.difficulty), "\(label) D \(card.difficulty!) vs \(g.difficulty)")
            #expect(card.due!.timeIntervalSince1970 == g.due, "\(label) due")
        }
    }

    @Test func longTermGoldenVectors() throws {
        let fixture = try FSRSFixture.load("fsrs_long_term")
        #expect(fixture.sequences.first?.reviews.map(\.stability).first == 2.3065)
        for seq in fixture.sequences { replay(seq) }
    }

    @Test func withStepsGoldenVectors() throws {
        let fixture = try FSRSFixture.load("fsrs_with_steps")
        #expect(fixture.sequences.count >= 8)
        for seq in fixture.sequences { replay(seq) }
    }

    @Test func roundsHalfToEven() throws {
        let cases = try #require(try FSRSFixture.load("fsrs_with_steps").roundCases)
        #expect(cases.contains { $0 == [2.5, 2] }, "fixture must include a .5 case")
        for c in cases {
            #expect(fsrs.nextInterval(c[0]) == Int(c[1]), "S \(c[0])")
        }
    }

    @Test func newCardStepIntervals() {
        let iv = StepScheduler().previewIntervals(MemoryState(), at: start)
        #expect(iv[.again] == 60)
        #expect(iv[.hard] == 330)
        #expect(iv[.good] == 600)
        #expect(iv[.easy] == 691_200) // 8 days
    }
}
