/// One way out, as the Safety page explains it.
struct EscapeHatch: Identifiable {
    let id: String
    let symbol: String
    let title: String
    /// The keys to press, if any.
    let keys: [String]
    let what: String
    var command: String?

    static var all: [EscapeHatch] { [
        EscapeHatch(id: "hotkey", symbol: "hand.raised.fill", title: "Kill switch", keys: ["⌃", "⌥", "⌘", "Esc"],
                    what: "Closes everything at once, from any app. Nothing comes back until 04:00 tomorrow. Free."),
        EscapeHatch(id: "defaults", symbol: "terminal", title: "Kill switch from Terminal", keys: [],
                    what: "Off until you set it back to false. Works even if the menu bar is hidden.",
                    command: KillSwitch.defaultsCommand),
        EscapeHatch(id: "file", symbol: "doc.badge.ellipsis", title: "Kill switch file", keys: [],
                    what: "While this file exists, nothing can appear. Works from SSH or another app.",
                    command: KillSwitch.fileCommand),
        EscapeHatch(id: "skip", symbol: "forward.end.fill", title: "Skip", keys: ["Esc"],
                    what: "Skips the words. On the gate press Esc twice; you see the cost first. Never refused."),
        EscapeHatch(id: "snooze", symbol: "zzz", title: "Snooze 5 minutes", keys: ["⌃", "⌥", "⌘", "S"],
                    what: "Free, 3 times a day. “Not now” on the 20-second warning snoozes 15 minutes."),
        EscapeHatch(id: "meeting", symbol: "person.2.wave.2.fill", title: "“I'm in a meeting” / “Joining a call”", keys: [],
                    what: "Closes now. Nothing for 60 minutes. Free when Tenaz sees a meeting, and twice a day anyway."),
        EscapeHatch(id: "pause", symbol: "pause.circle.fill", title: "Pause 1 hour", keys: [],
                    what: "From the menu bar. Free."),
        EscapeHatch(id: "auto", symbol: "video.slash.fill", title: "Meetings close it for you", keys: [],
                    what: "Mic, camera, a presentation or a calendar event closes any overlay or gate within 1 second, free."),
        EscapeHatch(id: "watchdog", symbol: "timer", title: "Time limits", keys: [],
                    what: "Words close after 90 seconds and the gate after 5 minutes, no matter what."),
        EscapeHatch(id: "quit", symbol: "xmark.octagon.fill", title: "Force Quit", keys: ["⌘", "⌥", "Esc"],
                    what: "Always works. Tenaz never restarts itself and never touches the login screen."),
    ] }
}
