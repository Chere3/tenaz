import SwiftUI

/// The plain, honest confirmation (design §6.7): the cost before anything happens, no guilt copy.
/// "Keep writing" is the default (Return); skipping is never refused. A paper sheet on the dimmed gate.
struct GateSkipConfirm: View {
    let price: GateSkipPrice
    let keepWriting: () -> Void
    let skip: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Skip the gate?")
                .font(Typography.displayM)
                .foregroundStyle(Tokens.ink)
            Text(price.responseCostOn
                 ? "Your contract says a skip costs 20 Vitality. You can use a Mercy token to pay 10 instead (\(price.mercyLeft) left this month)."
                 : "Skipping is free right now: Response cost is off in your contract. It still counts in your weekly review.")
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: keepWriting) {
                HStack(spacing: Tokens.Space.s) {
                    Text("Keep writing")
                    KeyCap("Return")
                }
            }
            .buttonStyle(.fat)
            .keyboardShortcut(.defaultAction)
            HStack(spacing: Tokens.Space.s) {
                Button(price.responseCostOn ? "Skip · −20 Vitality" : "Skip", systemImage: "forward.end") { skip(false) }
                if price.responseCostOn, price.mercyLeft > 0 {
                    Button("Use a Mercy token · −10", systemImage: "heart.circle") { skip(true) }
                }
            }
            .buttonStyle(.ink)
        }
        .padding(Tokens.Space.xl)
        .frame(width: 520)
        .background { RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper) }
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }
}
