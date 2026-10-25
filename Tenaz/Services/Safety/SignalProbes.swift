import AppKit
import CoreAudio
import CoreMediaIO
import EventKit
import IOKit.pwr_mgt
import TenazCore

/// Reads the "is the learner busy?" signals. Every probe returns nil when it can't tell,
/// and InterruptionPolicy treats nil as busy.
@MainActor
final class SignalProbes {
    private let eventStore = EKEventStore()
    var tenazUsesMicrophone = false

    /// Calendar access without prompting (no TCC dialog ever appears from a read).
    static var calendarGranted: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var calendarAuthorized: Bool { Self.calendarGranted }

    /// Asks for Calendar access (Settings button only; never from automation).
    @discardableResult
    func requestCalendarAccess() async -> Bool {
        (try? await eventStore.requestFullAccessToEvents()) ?? false
    }

    static var frontmostBundleId: String? { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }

    /// A call or chat app in front with no hard signal: sticker only (F14, critique #4).
    static var callOrChatFrontmost: Bool { MeetingApps.classify(frontmost: frontmostBundleId) == .callOrChat }

    func read() -> InterruptionSignals {
        InterruptionSignals(
            microphoneInUse: Self.microphoneRunning(),
            cameraInUse: Self.cameraRunning(),
            // Only presentation apps in front are a hard signal; call/chat apps limit to sticker mode.
            meetingAppFrontmost: MeetingApps.classify(frontmost: Self.frontmostBundleId) == .presentation,
            calendarEventNow: calendarEventNow(),
            displaySleepPreventedByOtherApp: Self.otherAppPreventsDisplaySleep(),
            focusModeOn: false,
            idleSeconds: CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!),
            tenazUsesMicrophone: tenazUsesMicrophone
        )
    }

    /// Any non-all-day event the learner hasn't declined, from 5 minutes ago to 5 minutes ahead. Broad on
    /// purpose: overlays and the gate stay away from every busy block (fail-safe).
    private func calendarEventNow() -> Bool? {
        currentEvents().map { !$0.isEmpty }
    }

    /// Exam Mode's rule: only an event that looks like a real meeting (another attendee, or a
    /// video-call link) counts, so personal time blocks never block or pause an exam.
    func calendarMeetingNow() -> Bool? {
        currentMeetings().map { !$0.isEmpty }
    }

    /// The first meeting's title, for "Your calendar shows <title> now".
    func calendarMeetingTitle() -> String? {
        currentMeetings()?.first?.title
    }

    private func currentMeetings() -> [EKEvent]? {
        currentEvents()?.filter { event in
            let others = event.attendees?.filter { !$0.isCurrentUser }.count ?? 0
            return CalendarMeeting.isMeeting(otherAttendees: others, texts: [event.url?.absoluteString, event.location, event.notes])
        }
    }

    /// Busy, timed, not-declined events around now; empty without Calendar access.
    private func currentEvents() -> [EKEvent]? {
        guard calendarAuthorized else { return [] } // no access: rely on the other signals
        let now = Date()
        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-300), end: now.addingTimeInterval(300), calendars: nil)
        return eventStore.events(matching: predicate).filter { event in
            guard !event.isAllDay, event.availability != .free else { return false }
            let declined = event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
            return !declined
        }
    }

    /// True when any input device (not only the default one) is running somewhere: a call app may
    /// use a chosen mic (AirPods, USB) while the default input is the built-in one. nil on errors.
    static func microphoneRunning() -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return nil }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return nil }
        for device in devices where hasInputStreams(device) {
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var a = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(device, &a, 0, nil, &runningSize, &running) == noErr else { return nil }
            if running != 0 { return true }
        }
        return false
    }

    private static func hasInputStreams(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    static func cameraRunning() -> Bool? {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == 0 else { return nil }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &used, &ids) == 0 else { return nil }
        for id in ids {
            var a = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            var running: UInt32 = 0
            var u: UInt32 = 0
            if CMIOObjectGetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &u, &running) == 0, running != 0 { return true }
        }
        return false
    }

    /// True when another process holds a "keep the display on" assertion (presentations, calls, video).
    static func otherAppPreventsDisplaySleep() -> Bool? {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess, let dict = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        for (pid, assertions) in dict where pid.int32Value != me {
            for a in assertions {
                let type = a[kIOPMAssertionTypeKey as String] as? String ?? ""
                let name = (a[kIOPMAssertionNameKey as String] as? String ?? "").lowercased()
                // Ignore the system's own short "user is active" pulses and our own apps.
                if type == kIOPMAssertionTypePreventUserIdleDisplaySleep || type == kIOPMAssertionTypeNoDisplaySleep {
                    if name.contains("useractivity") { continue }
                    return true
                }
            }
        }
        return false
    }
}
