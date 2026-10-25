import SwiftUI
import TenazCore

/// This week's hatch counts as one plain sentence (no display numerals for a page about rest).
struct HatchCountsRow: View {
    let counts: [HatchKind: Int]

    private let shown: [(HatchKind, String)] = [
        (.killSwitch, "Kill switch"), (.pause1h, "Pause 1 h"), (.meetingClaim, "In a meeting"), (.joiningCall, "Joining a call"),
        (.snooze, "Snooze"), (.overlaySkip, "Word skips"), (.emergencySkip, "Gate skips"),
    ]

    /// Only the non-zero counts, as one plain line ("Kill switch 1 · Snooze 2").
    private var usedLine: String {
        let used = shown.compactMap { kind, title in (counts[kind] ?? 0) > 0 ? "\(title) \(counts[kind] ?? 0)" : nil }
        return used.isEmpty ? "No ways out used this week." : used.joined(separator: " · ")
    }

    var body: some View {
        Text(usedLine)
            .font(Typography.body)
            .foregroundStyle(Tokens.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
