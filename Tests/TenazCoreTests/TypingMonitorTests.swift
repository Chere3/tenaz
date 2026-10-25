import Testing
@testable import TenazCore

struct TypingMonitorTests {
    @Test func largeInsertionIsFlaggedUnlessIME() {
        var m = TypingMonitor()
        #expect(m.record(at: 0, inserted: 1, deleted: 0, isIME: false) == nil)
        #expect(m.record(at: 1, inserted: 9, deleted: 0, isIME: false) == .largeInsertion(characters: 9))
        #expect(m.record(at: 2, inserted: 8, deleted: 0, isIME: false) == nil)
        #expect(m.record(at: 3, inserted: 30, deleted: 0, isIME: true) == nil)
    }

    @Test func superhumanSpeedWithoutBackspaceIsFlaggedOnce() {
        var m = TypingMonitor()
        var flags: [TypingFlag] = []
        // 4 chars every 0.25 s = 16 chars/s = 192 WPM, no deletions.
        for i in 0...60 {
            if let f = m.record(at: Double(i) * 0.25, inserted: 4, deleted: 0, isIME: false) { flags.append(f) }
        }
        #expect(flags.count == 1)
        guard case .fastTyping(let wpm) = flags[0] else { Issue.record("wrong flag"); return }
        #expect(wpm > 150)
    }

    @Test func fastTypingWithABackspaceIsNotFlagged() {
        var m = TypingMonitor()
        for i in 0...60 {
            #expect(m.record(at: Double(i) * 0.25, inserted: 4, deleted: i == 5 ? 1 : 0, isIME: false) == nil)
        }
    }

    @Test func normalTypingIsNotFlagged() {
        var m = TypingMonitor()
        // 5 chars/s = 60 WPM.
        for i in 0...200 {
            #expect(m.record(at: Double(i) * 0.2, inserted: 1, deleted: 0, isIME: false) == nil)
        }
    }

    @Test func pausesStartANewBurst() {
        var m = TypingMonitor()
        for i in 0..<20 { _ = m.record(at: Double(i) * 0.5, inserted: 1, deleted: 0, isIME: false) }
        // A 30 s pause, then one quick keystroke: must not inherit the old burst's duration.
        #expect(m.record(at: 40, inserted: 4, deleted: 0, isIME: false) == nil)
    }
}
