import SwiftUI

/// "Word 2 of 3" as thin segments (ink at 15 % / 100 %), (the "Word n of m" text lives in the accessibility label).
struct OverlayPips: View {
    let index: Int
    let total: Int
    var compact = false

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            HStack(spacing: 4) {
                ForEach(0 ..< total, id: \.self) { i in
                    Capsule()
                        .fill(Tokens.ink.opacity(i <= index ? 1 : 0.15))
                        .frame(height: 6)
                }
            }
            .frame(width: compact ? 54 : 150)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Word \(min(index + 1, total)) of \(total)")
    }
}
