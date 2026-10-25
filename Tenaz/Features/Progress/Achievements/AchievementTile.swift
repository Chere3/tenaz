import SwiftUI
import TenazCore

/// A badge on the shelf: click (or Space/Return) for the detail popover. Earned ones are big,
/// near ones medium with a ring, locked ones small silhouettes.
struct AchievementTile: View {
    let achievement: AchievementProgress
    var badge: CGFloat = 76
    @State private var showDetail = false
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 8) {
                AchievementStamp(achievement: achievement, size: badge)
                    .scaleEffect(hovering ? 1.06 : 1)
                Text(achievement.displayName)
                    .font(achievement.isUnlocked ? Typography.labelBold : Typography.label)
                    .foregroundStyle(achievement.isUnlocked ? Tokens.ink : Tokens.brand)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                caption
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.animation(.tap, reduceMotion: reduceMotion), value: hovering)
        .popover(isPresented: $showDetail, arrowEdge: .bottom) { AchievementDetail(achievement: achievement) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.displayName)
        .accessibilityValue(achievement.isUnlocked ? "Earned" : (achievement.definition.hidden ? "Secret" : AchievementLook.progressText(achievement)))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showDetail = true }
    }

    @ViewBuilder private var caption: some View {
        if let date = AchievementLook.unlockedText(achievement) {
            Text(date).font(Typography.caption).foregroundStyle(Tokens.brand)
        } else if achievement.definition.hidden {
            Text("Secret").font(Typography.caption).foregroundStyle(Tokens.brand.opacity(0.8))
        } else if achievement.value == nil {
            Text("Soon").font(Typography.caption).foregroundStyle(Tokens.brand.opacity(0.8))
        } else {
            Text(AchievementLook.progressText(achievement))
                .font(Typography.numeric(11))
                .foregroundStyle(Tokens.brand)
        }
    }
}
