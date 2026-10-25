import SwiftUI

/// The always-visible way out: pause intrusions for an hour (a text button; shows the end time
/// while paused and resumes on click), the quiet-hours and open links live in the popover footer.
struct PopoverSafetyRow: View {
    let actions: PopoverActions
    var pausedUntil: Date?

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            Button(action: actions.pauseIntrusions) {
                Label(pausedUntil.map { "Paused until \($0.formatted(date: .omitted, time: .shortened))" } ?? "Pause intrusions 1 h",
                      systemImage: pausedUntil == nil ? "pause.circle" : "play.circle.fill")
                    .foregroundStyle(Tokens.ink)
                    .font(Typography.label)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help(pausedUntil == nil ? "Nothing pops up for one hour. Free, always." : "Click to resume intrusions now.")
        }
        .buttonStyle(.plain)
    }
}
