import Foundation
import Testing
@testable import TenazCore

/// PLAN §5.3 intrusion rows. Every hatch test fails if the hatch is removed from the pipeline.
extension SafetyTests {
    typealias F = IntrusionFixture

    @Test func everythingShipsOff() {
        let defaults = UserDefaults(suiteName: "tenaz.tests.\(UUID().uuidString)")!
        let s = IntrusionSettings(defaults: defaults)
        #expect(!s.overlaysEnabled && !s.gateEnabled && !s.detectionOnlyAck)
        for surface in IntrusionSurface.allCases {
            #expect(F.decide(F.request(surface, settings: s)) == .deny("\(surface.rawValue) is off"))
        }
    }

    @Test func armedQuietMacShows() {
        #expect(F.decide(F.request(.overlay)) == .show(.poster))
        #expect(F.decide(F.request(.gate)) == .show(.poster))
    }

    @Test func killSwitchDismissesAllSurfaces() {
        let now = F.now
        let switches = [
            KillSwitchState(hotkeyUntil: KillSwitchState.hotkeyUntil(after: now, calendar: F.calendar)),
            KillSwitchState(defaultsKey: true),
            KillSwitchState(fileFlag: true),
        ]
        for ks in switches {
            #expect(ks.isEngaged(at: now))
            for surface in IntrusionSurface.allCases {
                let verdict = F.decide(F.request(surface) { $0.killSwitch = ks })
                guard case .deny = verdict else { Issue.record("\(ks) let \(surface) through"); continue }
                // Even the smoke path cannot get past a kill switch.
                guard case .deny = F.decide(F.request(surface) { $0.killSwitch = ks; $0.trigger = .smoke }) else {
                    Issue.record("smoke passed a kill switch"); continue
                }
            }
            // A visible surface must close.
            #expect(IntrusionDecider.mustCloseVisible(killSwitch: ks, signals: InterruptionSignals(), policy: InterruptionPolicy(), now: now) != nil)
        }
        // The hotkey lasts until the next 04:00 boundary, then intrusions may come back.
        let until = KillSwitchState.hotkeyUntil(after: now, calendar: F.calendar)
        #expect(until == F.date(3, 4))
        #expect(!KillSwitchState(hotkeyUntil: until).isEngaged(at: F.date(3, 4, 1)))
        // At 02:00 the learning day is still yesterday's, so the boundary is 04:00 the same morning.
        #expect(KillSwitchState.hotkeyUntil(after: F.date(3, 2), calendar: F.calendar) == F.date(3, 4))
    }

    @Test func cannotEnableWithoutCalendarOrAck() {
        #expect(!IntrusionEnableRule.canEnable(calendarGranted: false, acknowledged: false))
        #expect(IntrusionEnableRule.canEnable(calendarGranted: true, acknowledged: false))
        #expect(IntrusionEnableRule.canEnable(calendarGranted: false, acknowledged: true))
        // Turned on in defaults by hand without either: still denied.
        var s = F.armed
        s.detectionOnlyAck = false
        guard case .deny = F.decide(F.request(.overlay, settings: s)) else { Issue.record("enabled without calendar/ack"); return }
        #expect(F.decide(F.request(.overlay, settings: s) { $0.calendarGranted = true }) == .show(.poster))
    }

    @Test func capsAndQuietHours() {
        // Quiet hours 22:30-08:00, wrapping midnight.
        #expect(QuietHours.standard.contains(F.date(2, 23), calendar: F.calendar))
        #expect(QuietHours.standard.contains(F.date(3, 7, 59), calendar: F.calendar))
        #expect(!QuietHours.standard.contains(F.date(3, 8), calendar: F.calendar))
        #expect(!QuietHours.standard.contains(F.date(2, 22, 29), calendar: F.calendar))
        #expect(F.decide(F.request(.overlay, at: F.date(2, 23))) == .deny("quiet hours"))
        #expect(F.decide(F.request(.gate, at: F.date(3, 6))) == .deny("quiet hours"))

        // Overlays: 40 min apart, 8 a day.
        let last = F.now.addingTimeInterval(-39 * 60)
        guard case .deferred = F.decide(F.request { $0.history = IntrusionHistory(shown: [last]) }) else { Issue.record("gap"); return }
        #expect(F.decide(F.request { $0.history = IntrusionHistory(shown: [F.now.addingTimeInterval(-41 * 60)]) }) == .show(.poster))
        let eight = (0..<8).map { F.date(2, 8, 30).addingTimeInterval(Double($0) * 41 * 60) }
        guard case .deferred = F.decide(F.request(at: F.date(2, 21)) { $0.history = IntrusionHistory(shown: eight) }) else {
            Issue.record("daily cap"); return
        }
        // Settings can never raise the cap above 8 or the gap below 40 min.
        var loose = F.armed
        loose.overlaysPerDay = 50
        loose.overlayGapMinutes = 1
        loose.clamp()
        #expect(loose.overlaysPerDay == 8 && loose.overlayGapMinutes == 40)

        // Gates: 3 a day, 2 h apart.
        guard case .deferred = F.decide(F.request(.gate) { $0.history = IntrusionHistory(shown: [F.now.addingTimeInterval(-3600)]) }) else {
            Issue.record("gate gap"); return
        }
        let three = [F.date(2, 8, 30), F.date(2, 11), F.date(2, 14)]
        guard case .deferred = F.decide(F.request(.gate, at: F.date(2, 17)) { $0.history = IntrusionHistory(shown: three) }) else {
            Issue.record("gate cap"); return
        }
        #expect(F.decide(F.request(.gate, at: F.date(3, 9)) { $0.history = IntrusionHistory(shown: three) }) == .show(.poster))
    }

    @Test func pauseMeetingAndSnoozeHatchesBlock() {
        let later = F.now.addingTimeInterval(600)
        #expect(F.decide(F.request { $0.pausedUntil = later }) == .deny("paused"))
        #expect(F.decide(F.request(.gate) { $0.meetingUntil = later }) == .deny("in a meeting"))
        #expect(F.decide(F.request { $0.snoozedUntil = later }) == .deny("snoozed"))
        #expect(F.decide(F.request { $0.pausedUntil = F.now.addingTimeInterval(-1) }) == .show(.poster))
    }

    @Test func meetingSignalWhileVisibleClosesFree() {
        let signals: [InterruptionSignals] = [
            InterruptionSignals(microphoneInUse: true), InterruptionSignals(cameraInUse: true),
            InterruptionSignals(meetingAppFrontmost: true), InterruptionSignals(calendarEventNow: true),
            InterruptionSignals(focusModeOn: true), InterruptionSignals(microphoneInUse: nil),
        ]
        for s in signals {
            #expect(IntrusionDecider.mustCloseVisible(killSwitch: KillSwitchState(), signals: s, policy: InterruptionPolicy(), now: F.now) != nil)
            guard case .deferred = F.decide(F.request { $0.signals = s }) else { Issue.record("\(s) did not defer"); continue }
        }
        // Answering takes a while: idle time alone never closes a visible surface.
        #expect(IntrusionDecider.mustCloseVisible(killSwitch: KillSwitchState(), signals: InterruptionSignals(idleSeconds: 600),
                                                  policy: InterruptionPolicy(), now: F.now) == nil)
    }

    @Test func chatAppFrontmostAllowsStickerOnly() {
        #expect(MeetingApps.classify(frontmost: "com.microsoft.teams2") == .callOrChat)
        #expect(MeetingApps.classify(frontmost: "com.apple.iWork.Keynote") == .presentation)
        #expect(MeetingApps.classify(frontmost: "com.mitchellh.ghostty") == .other)
        #expect(F.decide(F.request { $0.callOrChatFrontmost = true }) == .show(.sticker))
        guard case .deferred = F.decide(F.request(.gate) { $0.callOrChatFrontmost = true }) else { Issue.record("gate over chat"); return }
    }

    @Test func watchdogClosesEachSurface() async {
        for surface in IntrusionSurface.allCases {
            let clock = TestClock(F.now)
            let fired = await SurfaceWatchdog.run(clock: clock, limit: SurfaceWatchdog.limit(for: surface)) {}
            #expect(fired)
            let elapsed = clock.now.timeIntervalSince(F.now)
            #expect(elapsed == (surface == .overlay ? 90 : 300))
        }
        #expect(SurfaceWatchdog.smoke <= .seconds(3))
        // Cancelled (closed first): it does not fire.
        let task = Task { await SurfaceWatchdog.run(clock: SystemClock(), limit: .seconds(30)) {} }
        task.cancel()
        #expect(await task.value == false)
    }

    @Test func hatchesAlwaysWorkButAreCounted() throws {
        let store = IntrusionStore(database: try .inMemory())
        for kind in HatchKind.allCases { try store.logHatch(kind, at: F.now) }
        try store.logHatch(.snooze, at: F.now)
        let day = DayBoundary.day(for: F.now)
        #expect(try store.hatchCount(.snooze, day: day) == 2)
        #expect(try store.hatchCounts(days: day...day).values.reduce(0, +) == HatchKind.allCases.count + 1)
    }
}
