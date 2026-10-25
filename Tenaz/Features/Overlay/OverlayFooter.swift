import SwiftUI

/// The rest of the escape ladder, always visible: snooze, "I'm in a meeting", and the kill switch.
struct OverlayFooter: View {
    let snoozesLeft: Int
    var compact = false
    let snooze: () -> Void
    let meeting: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            Button(action: snooze) {
                Text(compact ? "Snooze" : "Snooze 5 min ⌃⌥⌘S · \(snoozesLeft) left today")
            }
            .disabled(snoozesLeft == 0)
            Button(compact ? "Meeting" : "I'm in a meeting", systemImage: "person.2.wave.2", action: meeting)
                .labelStyle(CompactAwareLabelStyle(compact: compact))
                .help("Nothing from Tenaz for 60 minutes. Free.")
            if !compact { Text("·").foregroundStyle(Tokens.brand) } else { Spacer(minLength: 0) }
            Text(compact ? "Off: \(KillSwitch.hotkeyLabel)" : "Kill switch \(KillSwitch.hotkeyLabel)")
                .font(compact ? .system(size: 10, weight: .semibold, design: .rounded) : Typography.label)
                .foregroundStyle(Tokens.brand)
        }
        .buttonStyle(.ink)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: compact ? 11 : 14, weight: .semibold, design: .rounded))
    }
}

/// In the small card the meeting button drops its glyph so the row fits on one line.
private struct CompactAwareLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.title
        } else {
            Label(configuration)
        }
    }
}
