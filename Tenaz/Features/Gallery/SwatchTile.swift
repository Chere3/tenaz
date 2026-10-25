import SwiftUI
import TenazCore

/// One ink: printed chip of the colour, its token name, hex and contrast against the page.
struct SwatchTile: View {
    let name: String
    let role: KeyPath<Palette, HexColor>
    let palette: Palette

    private var hex: HexColor { palette[keyPath: role] }
    private var ratio: Double { Contrast.ratio(hex, palette.background) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Tokens.color(role))
                .frame(height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Tokens.ink.opacity(0.12), lineWidth: 1)
                }
            Text(name)
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
            HStack(spacing: 4) {
                Text(hex.description)
                Text(ratio, format: .number.precision(.fractionLength(2)))
                    .foregroundStyle(Tokens.brand)
            }
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(Tokens.ink)
        }
    }
}
