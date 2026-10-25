import SwiftUI

/// Corner toast (+10 XP, coin, streak): a flat pill that pops in.
struct Sticker: View {
    let text: String
    var systemImage: String
    var fill: Color = Tokens.gold
    var foreground: Color = Tokens.onGold

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .black))
            Text(text)
                .font(Typography.numeric(18))
        }
        .foregroundStyle(foreground)
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .padding(.vertical, 8)
        .background { Capsule().fill(fill) }
        .accessibilityElement(children: .combine)
    }
}

extension AnyTransition {
    /// Sticker entrance: scale 0.9 -> 1 and rotate -6° -> -2° (just opacity under Reduce Motion: pass `reduced`).
    static func peel(reduced: Bool) -> AnyTransition {
        reduced ? .opacity : .modifier(active: PeelEffect(progress: 0), identity: PeelEffect(progress: 1))
    }
}
