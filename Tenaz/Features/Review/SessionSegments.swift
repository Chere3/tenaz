import SwiftUI

/// Session progress as thin segments along the top: one per card, answered = ink, to come = ink 15 %.
/// Long sessions (more than 30 cards) fall back to one continuous track so segments never turn to dust.
struct SessionSegments: View {
    let answered: Int
    let total: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let count = max(total, 1)
            if count <= 30 {
                let gap: CGFloat = count > 20 ? 4 : 6
                let width = max(2, (proxy.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
                HStack(spacing: gap) {
                    ForEach(0 ..< count, id: \.self) { index in
                        Capsule()
                            .fill(Tokens.ink.opacity(index < answered ? 1 : 0.15))
                            .frame(width: width)
                    }
                }
            } else {
                let fraction = min(1, Double(answered) / Double(count))
                Capsule()
                    .fill(Tokens.ink.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Tokens.ink).frame(width: proxy.size.width * fraction)
                    }
            }
        }
        .frame(height: 6)
        .animation(Motion.animation(.settle, reduceMotion: reduceMotion), value: answered)
        .accessibilityElement()
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(answered) of \(total)")
    }
}
