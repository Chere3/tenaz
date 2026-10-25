import Foundation
import Testing
@testable import TenazCore

struct OverlayTests {
    typealias F = IntrusionFixture
    typealias Q = QueueFixture

    private func item(_ id: String, _ type: CardType) -> SessionItem {
        SessionItem(card: Q.reviewCard(id, type), note: Q.note(id),
                    prompt: CardPrompt(type: type, text: id, hint: nil, options: [], correctOption: nil, expected: id, accepted: []))
    }

    @Test func batchOnlyAutoScorableTypes() {
        let items = [item("a", .production), item("b", .recognition), item("c", .spelling), item("d", .cloze),
                     item("e", .recall), item("f", .collocation)]
        let batch = OverlayBatch.pick(items)
        #expect(batch.map(\.card.type) == [.recognition, .cloze, .recall])
        #expect(!batch.contains { $0.card.type == .production || $0.card.type == .spelling })
    }

    @Test func earlyKeystrokesIgnored() {
        let shown = F.now
        let guardrail = EarlyInputGuard(shownAt: shown)
        #expect(!guardrail.acceptsTyping(at: shown.addingTimeInterval(0.3)))
        #expect(guardrail.acceptsTyping(at: shown.addingTimeInterval(0.6)))
        #expect(!guardrail.acceptsSubmit(at: shown.addingTimeInterval(0.9)))
        #expect(guardrail.acceptsSubmit(at: shown.addingTimeInterval(1.0)))
    }

    @Test func waitsForTypingPause() {
        #expect(!EarlyInputGuard.canShow(secondsSinceLastKey: 0.5))
        #expect(EarlyInputGuard.canShow(secondsSinceLastKey: 2.5))
    }

    @Test func deferWhenGuardDefers() {
        guard case .deferred = F.decide(F.request { $0.signals = InterruptionSignals(cameraInUse: true) }) else {
            Issue.record("camera did not defer"); return
        }
    }

    @Test func triggersAtBoundariesOnly() {
        var t = ActivityTracker()
        #expect(t.activated("com.apple.dt.Xcode", at: F.now) == nil)
        #expect(t.activated("com.apple.Safari", at: F.now.addingTimeInterval(10 * 60)) == nil)
        #expect(t.activated("com.mitchellh.ghostty", at: F.now.addingTimeInterval(40 * 60)) == .appSwitch)
        #expect(t.idle(seconds: 400) == nil)
        #expect(t.idle(seconds: 2) == .idleReturn)
        #expect(t.idle(seconds: 2) == nil)
        var off = F.armed
        off.triggers.appSwitch = false
        #expect(F.decide(F.request(settings: off)) == .deny("trigger appSwitch is off"))
    }

    @Test func missedWordReturnsInOneMinute() throws {
        var session = ReviewSession(items: [item("w", .cloze)], surface: .overlay)
        _ = session.next(now: F.now)
        let outcome = try session.submit(.typed("zzz"), durationMs: 2000, inputMode: .typed, at: F.now)
        #expect(outcome.rating == Rating.again)
        let back = try #require(outcome.comesBackAt)
        #expect(back.timeIntervalSince(F.now) <= 10 * 60)
    }
}
