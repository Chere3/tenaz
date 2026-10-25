import SwiftUI

/// A segmented meter ([######----] 62): ten printed cells, glyph + word + number.
/// At 30 or less it turns red and says "Low", so the state never relies on colour alone.
struct MeterBar: View {
    let kind: MeterKind
    /// 0...100.
    let value: Double

    private var isLow: Bool { value <= 30 }

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: isLow ? "exclamationmark.triangle.fill" : kind.systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isLow ? Tokens.wrong : Tokens.ink)
                .frame(width: 18)
            Text(kind.title)
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
                .frame(width: 58, alignment: .leading)
            MeterCells(fraction: value / 100, fill: isLow ? Tokens.wrong : kind.fill)
                .frame(height: 16)
            Text(isLow ? "Low \(Int(value))" : "\(Int(value))")
                .font(Typography.numeric(14))
                .foregroundStyle(isLow ? Tokens.wrong : Tokens.ink)
                .frame(minWidth: 26, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
        .accessibilityValue("\(Int(value)) of 100\(isLow ? ", low" : "")")
    }
}
