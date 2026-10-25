import SwiftUI
import TenazCore

/// Mercy tokens left this month, as three printed hearts (filled = left).
struct MercyTokens: View {
    let left: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<PenaltyPolicy.mercyTokensPerMonth, id: \.self) { i in
                    Image(systemName: i < left ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(i < left ? Tokens.tenaShade : Tokens.ink.opacity(0.4))
                }
            }
            Text("Mercy tokens · \(left) of \(PenaltyPolicy.mercyTokensPerMonth) this month")
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
            Text("A token halves the gate's skip cost. Never required.")
                .font(Typography.caption)
                .foregroundStyle(Tokens.brand)
        }
        .accessibilityElement(children: .combine)
    }
}
