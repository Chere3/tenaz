import Foundation
import Testing
@testable import TenazCore

struct SafetyTests {
    let policy = InterruptionPolicy()

    @Test func quietMacAllows() {
        #expect(policy.decide(InterruptionSignals()) == .allow)
    }

    @Test func meetingSignalsDefer() {
        #expect(policy.decide(InterruptionSignals(microphoneInUse: true)) != .allow)
        #expect(policy.decide(InterruptionSignals(cameraInUse: true)) != .allow)
        #expect(policy.decide(InterruptionSignals(meetingAppFrontmost: true)) != .allow)
        #expect(policy.decide(InterruptionSignals(calendarEventNow: true)) != .allow)
        #expect(policy.decide(InterruptionSignals(displaySleepPreventedByOtherApp: true)) != .allow)
    }

    @Test func unknownReadingsDefer() {
        #expect(policy.decide(InterruptionSignals(microphoneInUse: nil)) != .allow)
        #expect(policy.decide(InterruptionSignals(cameraInUse: nil)) != .allow)
        #expect(policy.decide(InterruptionSignals(idleSeconds: nil)) != .allow)
    }

    @Test func ownMicrophoneUseDoesNotDefer() {
        #expect(policy.decide(InterruptionSignals(microphoneInUse: true, tenazUsesMicrophone: true)) == .allow)
    }

    @Test func awayDefers() {
        #expect(policy.decide(InterruptionSignals(idleSeconds: 600)) != .allow)
    }

    @Test func meetingPauseDefersUntilItEnds() {
        var p = InterruptionPolicy()
        let now = Date()
        p.snoozedUntil = now.addingTimeInterval(3600)
        #expect(p.decide(InterruptionSignals(), now: now) != .allow)
        #expect(p.decide(InterruptionSignals(), now: now.addingTimeInterval(3601)) == .allow)
    }

    @Test func focusCanBeIgnoredByChoice() {
        var p = InterruptionPolicy()
        #expect(p.decide(InterruptionSignals(focusModeOn: true)) != .allow)
        p.respectFocus = false
        #expect(p.decide(InterruptionSignals(focusModeOn: true)) == .allow)
    }

    @Test func scheduleCapsFrequency() {
        var s = OverlaySchedule(minimumGap: 1200, maxPerDay: 2)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let t = ISO8601DateFormatter().date(from: "2026-10-22T12:00:00Z")!
        #expect(s.canShow(at: t, calendar: cal))
        s.record(t)
        #expect(!s.canShow(at: t.addingTimeInterval(60), calendar: cal))
        #expect(s.canShow(at: t.addingTimeInterval(1300), calendar: cal))
        s.record(t.addingTimeInterval(1300))
        #expect(!s.canShow(at: t.addingTimeInterval(5000), calendar: cal))
        #expect(s.canShow(at: t.addingTimeInterval(86400), calendar: cal))
    }
}
