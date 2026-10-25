import SwiftUI

/// "9 day streak" as plain text with a flame: glyph + number + word, so it reads without colour.
struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
            Text("\(days) \(days == 1 ? "day" : "days")")
                .font(Typography.labelBold)
        }
        .foregroundStyle(Tokens.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak \(days) days")
    }
}
