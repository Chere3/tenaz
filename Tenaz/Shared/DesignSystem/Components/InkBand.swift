import SwiftUI

/// Time drawn, not written: a band that drains like ink running out, with optional minute notches.
/// Brand ink until the last 25 %, then orange, then deep orange for the last 10 %. Always paired with
/// a tabular readout for people who want the number.
struct InkBand: View {
    /// 1 = full, 0 = empty.
    var remaining: Double
    var notches = 0
    var readout: String?

    private var fill: Color {
        switch remaining {
        case ...0.10: Tokens.accentText
        case ...0.25: Tokens.accent
        default: Tokens.ink
        }
    }

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Canvas { context, size in
                let track = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerRadius: size.height / 2)
                context.fill(track, with: .color(Tokens.ink.opacity(0.12)))
                let level = max(0, min(1, remaining))
                let width = size.width * level
                context.drawLayer { layer in
                    layer.clip(to: track)
                    layer.fill(Path(CGRect(x: 0, y: 0, width: width, height: size.height)), with: .color(fill))
                    if notches > 1 {
                        var ticks = Path()
                        for i in 1 ..< notches {
                            let x = size.width * CGFloat(i) / CGFloat(notches)
                            ticks.move(to: CGPoint(x: x, y: size.height * 0.62))
                            ticks.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        layer.stroke(ticks, with: .color(Tokens.ink), lineWidth: 1.5)
                    }
                }
            }
            .frame(height: 12)
            if let readout {
                Text(readout)
                    .font(Typography.numeric(15))
                    .foregroundStyle(remaining <= 0.10 ? Tokens.accentText : Tokens.ink)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue(readout ?? "\(Int(remaining * 100)) percent")
    }
}
