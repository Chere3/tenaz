import SwiftUI

/// End of the batch (tier M when all were right): the score as the hero, and the XP.
struct OverlayDoneStamp: View {
    let correct: Int
    let total: Int
    let xp: Int
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : Tokens.Space.xs) {
            Text(correct == total ? "All done" : "Done")
                .font(Typography.display(compact ? 40 : 150))
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(correct) of \(total) remembered" + (xp > 0 ? " · +\(xp) XP" : ""))
                .font(.system(size: compact ? 14 : 26, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.ink)
        }
        .accessibilityElement(children: .combine)
    }
}
