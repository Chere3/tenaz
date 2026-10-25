import Foundation

/// Which calendar events count as a *meeting* for Exam Mode. Many people time-block their whole day
/// ("Sleep", "Shower", "Project work 09:00-20:00"), so "any busy event" would block every exam all day.
/// A meeting has at least one other attendee, or a video-call link in its URL, location or notes.
/// Overlays and the gate keep the broad "any busy event" rule (fail-safe); this is the exam's rule.
public enum CalendarMeeting {
    public static let callLinkMarkers = [
        "zoom.us", "zoom.com", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com",
        "facetime.apple.com", "whereby.com", "discord.gg", "discord.com/channels", "gotomeeting", "chime.aws",
    ]

    public static func isMeeting(otherAttendees: Int, texts: [String?]) -> Bool {
        if otherAttendees > 0 { return true }
        return texts.contains { text in
            guard let t = text?.lowercased(), !t.isEmpty else { return false }
            return callLinkMarkers.contains { t.contains($0) }
        }
    }
}
