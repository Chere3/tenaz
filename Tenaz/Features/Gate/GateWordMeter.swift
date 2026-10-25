import SwiftUI

/// Word count as one thin continuous bar up to the target, with one notch at the minimum. Flat: ink only.
struct GateWordMeter: View {
    let words: Int
    let minWords: Int
    let target: Int

    var body: some View {
        Canvas { context, size in
            let h: CGFloat = 6
            let top = (size.height - h) / 2
            let total = CGFloat(max(1, target))
            let track = Path(roundedRect: CGRect(x: 0, y: top, width: size.width, height: h), cornerRadius: h / 2)
            context.fill(track, with: .color(Tokens.ink.opacity(0.15)))
            let level = min(1, CGFloat(words) / total)
            if level > 0 {
                let bar = Path(roundedRect: CGRect(x: 0, y: top, width: size.width * level, height: h), cornerRadius: h / 2)
                context.fill(bar, with: .color(Tokens.ink.opacity(words >= minWords ? 1 : 0.6)))
            }
            let x = size.width * CGFloat(minWords) / total
            var mark = Path()
            mark.move(to: CGPoint(x: x, y: top - 4))
            mark.addLine(to: CGPoint(x: x, y: top + h + 4))
            context.stroke(mark, with: .color(Tokens.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .accessibilityElement()
        .accessibilityLabel("Words")
        .accessibilityValue("\(words) of \(target), at least \(minWords)")
    }
}
