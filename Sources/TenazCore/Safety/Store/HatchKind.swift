/// Every escape hatch (`hatch_event.kind`). Hatches always work; they are counted, never blocked.
public enum HatchKind: String, Codable, CaseIterable, Sendable {
    case killSwitch, pause1h, meetingClaim, joiningCall, snooze, emergencySkip, overlaySkip, notNow
}
