import SwiftUI
import TenazCore

/// One rule as a row of the list: what it does, what it costs, its state, and the one button that changes it.
struct ContractRuleCard: View {
    let kind: PenaltyRuleKind
    @Bindable var model: ContractModel
    @State private var confirming = false

    private var on: Bool { model.isOn(kind) }
    private var pending: PenaltyRuleRecord? { model.pending(kind) }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.m) {
            Image(systemName: kind.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Tokens.brand)
                .frame(width: 26)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Tokens.Space.xs) {
                    Text(kind.title)
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                    if !kind.canBeEnabled {
                        Chip("Not yet", state: .locked)
                    } else if on {
                        Chip("On", systemImage: "bolt.fill", state: .active)
                    }
                    Spacer(minLength: Tokens.Space.m)
                    if pending == nil, kind.canBeEnabled { toggleButton }
                }
                Text(kind.explanation)
                    .font(Typography.body)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(kind.costLine)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                if let chosen = model.chosenOn(kind) {
                    Text("You chose this on \(chosen.formatted(date: .abbreviated, time: .omitted)).")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
                if let pending {
                    ContractPendingLine(change: pending) { model.cancel(pending) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Tokens.Space.m)
        .opacity(kind.canBeEnabled ? 1 : 0.75)
    }

    private var toggleButton: some View {
        Button(on ? "Turn off" : "Turn on") {
            if on { model.request(kind, on: false) } else { confirming = true }
        }
        .buttonStyle(.ink)
        .help(on ? "Turning it off takes 24 hours." : "Starts at 04:00.")
        .confirmationDialog("Turn on “\(kind.title)”?", isPresented: $confirming) {
            Button("Turn on at 04:00") { model.request(kind, on: true) }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("\(kind.explanation) You can turn it off later; that takes 24 hours.")
        }
    }
}
