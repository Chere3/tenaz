import SwiftUI
import TenazCore

/// The Contract's content: a calm paper page. A title, the two numbers that matter, then lists.
struct ContractPage: View {
    @Bindable var model: ContractModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            HStack(alignment: .center, spacing: Tokens.Space.l) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text("Your contract")
                        .font(Typography.displayL)
                        .foregroundStyle(Tokens.ink)
                    Text("Rules you choose for yourself, in a calm moment. All of them start off.")
                        .font(Typography.body)
                        .foregroundStyle(Tokens.ink)
                    Text("Turning a rule on starts at 04:00. Turning it off takes 24 hours.")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
                Spacer(minLength: 0)
                TenaView(mood: model.recoveryMode ? .regenerating : .focused, stage: .juvenile, size: 170)
                    .frame(height: 130, alignment: .top)
                    .clipped()
            }
            HStack(alignment: .top, spacing: Tokens.Space.xxl) {
                MercyTokens(left: model.mercyLeft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Vitality").font(Typography.labelBold).foregroundStyle(Tokens.ink)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Tokens.ink.opacity(0.15))
                                Capsule().fill(Tokens.ink).frame(width: geo.size.width * CGFloat(max(0, min(100, model.vitality))) / 100)
                            }
                        }
                        .frame(height: 6)
                        Text("\(model.vitality)").font(Typography.numeric(15)).foregroundStyle(Tokens.ink)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Vitality \(model.vitality) of 100")
                    Text(model.recoveryMode ? "Recovery mode: no more penalties today." : "Vitality only moves when Response cost is on.")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !model.allPending.isEmpty {
                ContractSection(title: "Pending changes") {
                    ForEach(Array(model.allPending.enumerated()), id: \.element.id) { i, change in
                        if i > 0 { ContractRule() }
                        HStack {
                            Text(change.kind.title).font(Typography.labelBold).foregroundStyle(Tokens.ink)
                            Spacer()
                            ContractPendingLine(change: change) { model.cancel(change) }
                        }
                        .padding(.vertical, Tokens.Space.s)
                    }
                }
            }
            ContractSection(title: "The rules") {
                ForEach(Array(PenaltyRuleKind.allCases.enumerated()), id: \.element) { i, kind in
                    if i > 0 { ContractRule() }
                    ContractRuleCard(kind: kind, model: model)
                }
            }
            ContractCostTable()
            ExperimentLogSummary(stats: model.weekStats, suggested: model.suggestedToDisable)
        }
    }
}
