import SwiftUI
import TenazCore

/// What each thing costs under Response cost, and the caps that always protect you.
struct ContractCostTable: View {
    private let costs: [(String, String)] = [
        ("Skip a word batch (Esc)", "−3 Vitality"),
        ("Emergency skip on the gate", "−20 Vitality (−10 with a Mercy token)"),
        ("Typed in the gate, then left it", "−10 Vitality"),
        ("Gate timed out while you were away", "Free"),
        ("Missed your daily minimum", "−10 Vitality, −20 Scales"),
        ("“I'm in a meeting” with no meeting, after the 2nd time in a day", "−3 Vitality (only with a visible work calendar)"),
        ("Kill switch, Pause 1 h, quiet hours", "Always free"),
    ]
    private let caps: [(String, String)] = [
        ("shield.lefthalf.filled", "Never more than −30 Vitality in one day."),
        ("timer", "Never more than 5 minutes of penalty tasks in one day."),
        ("heart.text.square", "After 3 penalties in a day: recovery mode. Easier items, no more penalties today."),
        ("arrow.down.to.line", "Vitality never goes below 15."),
        ("snowflake", "After 2 missed days in a row the drain stops. Coming back gives +10 Vitality."),
        ("star.circle", "Your level, XP, learned words and your Mac are never touched."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            ContractSection(title: "What it costs", note: "Only when Response cost is on. With it off, everything here is free.") {
                ForEach(Array(costs.enumerated()), id: \.offset) { i, row in
                    if i > 0 { ContractRule() }
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.0).font(Typography.body).foregroundStyle(Tokens.ink)
                        Spacer(minLength: Tokens.Space.m)
                        Text(row.1).font(Typography.title).foregroundStyle(Tokens.ink).multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, Tokens.Space.s)
                }
            }
            ContractSection(title: "Caps that always protect you") {
                ForEach(Array(caps.enumerated()), id: \.offset) { i, cap in
                    if i > 0 { ContractRule() }
                    Label {
                        Text(cap.1).font(Typography.body).foregroundStyle(Tokens.ink)
                    } icon: {
                        Image(systemName: cap.0).foregroundStyle(Tokens.brand)
                    }
                    .padding(.vertical, Tokens.Space.s)
                }
            }
        }
    }
}
