import SwiftUI
import TenazCore

/// A "closest to unlock" row: the next goal, always visible (short feedback loop, R3).
struct ClosestCard: View {
    let achievement: AchievementProgress

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.m) {
            AchievementStamp(achievement: achievement, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.displayName)
                    .font(Typography.display(22, weight: 800))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(achievement.definition.description)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .lineLimit(1)
            }
            Spacer(minLength: Tokens.Space.s)
            Text(AchievementLook.progressText(achievement))
                .font(Typography.numeric(17))
                .foregroundStyle(Tokens.ink)
                .fixedSize()
        }
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
