import SwiftUI

/// Ten cells filled left to right; the leading edge cell fills partially. Flat: empty cells are ink at 12 %.
struct MeterCells: View {
    let fraction: Double
    let fill: Color
    var cells = 10

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 3
            let width = (size.width - gap * CGFloat(cells - 1)) / CGFloat(cells)
            let level = max(0, min(1, fraction)) * Double(cells)
            for i in 0 ..< cells {
                let rect = CGRect(x: CGFloat(i) * (width + gap), y: 0, width: width, height: size.height).insetBy(dx: 0.75, dy: 0.75)
                let cell = Path(roundedRect: rect, cornerRadius: 4)
                context.fill(cell, with: .color(Tokens.ink.opacity(0.12)))
                let amount = min(1, max(0, level - Double(i)))
                if amount > 0 {
                    context.drawLayer { layer in
                        layer.clip(to: cell)
                        let filled = CGRect(x: rect.minX, y: rect.minY, width: rect.width * amount, height: rect.height)
                        layer.fill(Path(filled), with: .color(fill))
                    }
                }
            }
        }
    }
}
