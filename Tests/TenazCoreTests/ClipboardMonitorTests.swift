import Testing
@testable import TenazCore

struct ClipboardMonitorTests {
    @Test func firstObservationIsOnlyABaseline() {
        var m = ClipboardMonitor()
        #expect(m.observe(changeCount: 41) == nil)
        #expect(m.observe(changeCount: 41) == nil)
    }

    @Test func changeCountDeltaIsFlagged() {
        var m = ClipboardMonitor()
        _ = m.observe(changeCount: 10)
        #expect(m.observe(changeCount: 11) == ClipboardFlag(changes: 1))
        #expect(m.observe(changeCount: 11) == nil)
        #expect(m.observe(changeCount: 14) == ClipboardFlag(changes: 3))
    }
}
