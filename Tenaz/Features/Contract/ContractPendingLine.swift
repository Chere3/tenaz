import SwiftUI
import TenazCore

/// "Turns on at 04:00 · Cancel" / "Turns off in 23 h · Cancel".
struct ContractPendingLine: View {
    let change: PenaltyRuleRecord
    let cancel: () -> Void

    private var when: Date { Date(timeIntervalSince1970: Double(change.effectiveAt) / 1000) }

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            Image(systemName: "hourglass").font(.system(size: 12, weight: .bold)).foregroundStyle(Tokens.brand)
            Text(change.enabled ? "Turns on \(when.formatted(.relative(presentation: .named)))" : "Turns off \(when.formatted(.relative(presentation: .named)))")
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
            Button("Cancel", action: cancel).buttonStyle(.ink).font(Typography.label)
        }
    }
}
