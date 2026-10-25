import SwiftUI
import TenazCore

/// The real safeguard (F10): how often each rule fired and how often you escaped it this week.
/// A rule escaped more than 60% of the time for two weeks is suggested for turning off.
struct ExperimentLogSummary: View {
    let stats: [PenaltyRuleKind: PenaltyExperimentLog.Stats]
    let suggested: [String]

    private var active: [(PenaltyRuleKind, PenaltyExperimentLog.Stats)] {
        PenaltyRuleKind.allCases.compactMap { k in stats[k].flatMap { $0.shown > 0 ? (k, $0) : nil } }
    }

    var body: some View {
        ContractSection(title: "This week",
                        note: "Is each rule helping? If you escape a rule most of the time, Tenaz will suggest turning it off.") {
            if active.isEmpty {
                Text("Nothing yet. Rules you turn on will show here: how often they fired and how often you escaped.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Tokens.Space.s)
            } else {
                ForEach(Array(active.enumerated()), id: \.offset) { i, pair in
                    if i > 0 { ContractRule() }
                    HStack {
                        Text(pair.0.title).font(Typography.labelBold).foregroundStyle(Tokens.ink)
                        Spacer()
                        Text("fired \(pair.1.fired) · escaped \(pair.1.escaped) · \(Int(pair.1.escapeRate * 100))% escaped")
                            .font(Typography.numeric(13)).foregroundStyle(Tokens.ink)
                        if suggested.contains(pair.0.rawValue) { Chip("Try turning off", systemImage: "lightbulb", state: .active) }
                    }
                    .padding(.vertical, Tokens.Space.s)
                }
            }
        }
    }
}
