import SwiftUI

/// Spacing scale, the radii and the hairline rule. Flat fills, no outlines.
struct GalleryShapes: View {
    private static let steps: [CGFloat] = [4, 8, 12, 16, 24, 32, 48, 72]

    var body: some View {
        HStack(alignment: .bottom, spacing: Tokens.Space.l) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Self.steps, id: \.self) { step in
                    VStack(spacing: 4) {
                        Rectangle().fill(Tokens.ink).frame(width: step / 2.2 + 2, height: step)
                        Text("\(Int(step))").font(Typography.caption).foregroundStyle(Tokens.ink)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: Tokens.Space.s) {
                shape("14", "control", Tokens.Radius.control, width: 56, height: 56)
                shape("20", "card", Tokens.Radius.card, width: 72, height: 56)
                shape("24", "sheet", Tokens.Radius.sheet, width: 84, height: 56, fill: Tokens.paper)
                shape("pill", "pill", Tokens.Radius.pill, width: 72, height: 40)
            }
        }
    }

    private func shape(_ label: String, _ name: String, _ radius: CGFloat, width: CGFloat, height: CGFloat, fill: Color = Tokens.card) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
                .frame(width: width, height: height)
                .background { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill) }
                .background { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Tokens.ink.opacity(0.08)) }
            Text(name).font(Typography.caption).foregroundStyle(Tokens.brand).fixedSize()
        }
    }
}
