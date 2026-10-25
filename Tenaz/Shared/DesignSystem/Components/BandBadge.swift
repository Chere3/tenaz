import SwiftUI
import TenazCore

/// A TOEFL-style band (1-6 in 0.5 steps) on a flat gold disc, with its CEFR label.
/// With `upper`, shows the honest range ("3.5 to 4.0"), never rounded up.
struct BandBadge: View {
    let band: Double
    var upper: Double?
    var size: CGFloat = 84

    private var cefr: String { AbilityEstimator.cefr(forBand: band).label }

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            ZStack {
                Circle().fill(Tokens.gold)
                VStack(spacing: -1) {
                    Text(band, format: .number.precision(.fractionLength(1)))
                        .font(Typography.display(size * 0.32))
                        .foregroundStyle(Tokens.onGold)
                    Text(cefr)
                        .font(.system(size: max(10, size * 0.14), weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.onGold)
                }
            }
            .frame(width: size, height: size)
            if let upper {
                Text("\(band.formatted(.number.precision(.fractionLength(1)))) to \(upper.formatted(.number.precision(.fractionLength(1))))")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Band \(band.formatted()), \(cefr)")
    }
}
