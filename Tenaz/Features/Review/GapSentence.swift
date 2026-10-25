import SwiftUI

/// A sentence with its `____` gap drawn as a 6 pt ink underline, set word by word in the prompt face.
struct GapSentence: View {
    let sentence: String
    var size: CGFloat = 50

    private enum Token: Hashable {
        case word(Int, String)
        case gap(Int)
    }

    private var tokens: [Token] {
        var result: [Token] = []
        let parts = sentence.components(separatedBy: "____")
        for (index, part) in parts.enumerated() {
            if index > 0 { result.append(.gap(result.count)) }
            for word in part.split(separator: " ") {
                result.append(.word(result.count, String(word)))
            }
        }
        return result
    }

    var body: some View {
        WordFlow(spacing: size * 0.24, lineSpacing: -size * 0.1) {
            ForEach(tokens, id: \.self) { token in
                switch token {
                case let .word(_, word):
                    Text(word)
                case .gap:
                    // An invisible run sets the height and baseline; the bar sits on the baseline.
                    Text("mmmm")
                        .hidden()
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(Tokens.ink)
                                .frame(height: 6)
                                .offset(y: -size * 0.22)
                        }
                }
            }
        }
        .font(Typography.display(size, weight: 800))
        .foregroundStyle(Tokens.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sentence.replacingOccurrences(of: "____", with: "blank"))
    }
}

/// Left-aligned flow of equal-height runs (words of one font), wrapping at the proposed width.
private struct WordFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    private func rows(for subviews: Subviews, width: CGFloat) -> [[(Int, CGSize)]] {
        var rows: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append((index, size))
            x += size.width + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let lines = rows(for: subviews, width: width)
        var height: CGFloat = 0
        var widest: CGFloat = 0
        for (i, line) in lines.enumerated() {
            let lineHeight = line.map(\.1.height).max() ?? 0
            height += lineHeight + (i > 0 ? lineSpacing : 0)
            let lineWidth = line.map(\.1.width).reduce(0, +) + spacing * CGFloat(max(0, line.count - 1))
            widest = max(widest, lineWidth)
        }
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for line in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            let lineHeight = line.map(\.1.height).max() ?? 0
            for (index, size) in line {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += lineHeight + lineSpacing
        }
    }
}
