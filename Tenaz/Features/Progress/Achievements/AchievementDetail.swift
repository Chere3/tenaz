import SwiftUI
import TenazCore

/// The popover behind a stamp: what it is, how close you are, what it pays.
struct AchievementDetail: View {
    let achievement: AchievementProgress

    private var d: AchievementDefinition { achievement.definition }
    private var secret: Bool { d.hidden && !achievement.isUnlocked }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(alignment: .top, spacing: Tokens.Space.m) {
                AchievementStamp(achievement: achievement, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(achievement.displayName).font(Typography.display(24)).foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Chip(AchievementLook.rarity(achievement).title, systemImage: "seal")
                        Chip(AchievementLook.typeTitle(d.type), state: achievement.isUnlocked ? .done : .idle)
                    }
                }
            }
            Text(secret ? (d.hint ?? "A secret. Keep learning and it will find you.") : d.description)
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let date = AchievementLook.unlockedText(achievement) {
                Label("Earned \(date)", systemImage: "checkmark.seal.fill")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.correct)
            } else if !secret {
                VStack(alignment: .leading, spacing: 6) {
                    MeterCells(fraction: achievement.fraction, fill: Tokens.ink).frame(height: 14)
                    Text(AchievementLook.progressText(achievement))
                        .font(Typography.numeric(13))
                        .foregroundStyle(Tokens.brand)
                }
            }
            HStack(spacing: Tokens.Space.xs) {
                Image(systemName: "star.fill").font(.system(size: 11, weight: .black))
                Text("+\(d.reward.xp) XP")
                if d.reward.scales > 0 {
                    Text("·")
                    Text("+\(d.reward.scales) scales")
                }
            }
            .font(Typography.labelBold)
            .foregroundStyle(Tokens.ink)
        }
        .padding(Tokens.Space.l)
        .frame(width: 320, alignment: .leading)
        .background(Tokens.paper)
    }
}
