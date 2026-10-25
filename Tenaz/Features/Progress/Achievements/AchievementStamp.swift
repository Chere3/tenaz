import SwiftUI
import TenazCore

/// One achievement as a flat badge. Earned: full-colour fill and glyph. Near (measurable, started):
/// a progress ring around the glyph. Locked or secret: a silhouette in ink at 12 %.
struct AchievementStamp: View {
    let achievement: AchievementProgress
    var size: CGFloat = 84

    enum Look { case earned, near, locked }

    static func look(_ a: AchievementProgress) -> Look {
        if a.isUnlocked { return .earned }
        if !a.definition.hidden, a.value != nil, a.fraction > 0 { return .near }
        return .locked
    }

    private var shape: StampShape { StampShape(perforated: false) }

    var body: some View {
        ZStack {
            switch Self.look(achievement) {
            case .earned:
                shape.fill(Tokens.gold)
                glyph(size * 0.38).foregroundStyle(Tokens.onGold)
            case .near:
                Circle().stroke(Tokens.ink.opacity(0.12), lineWidth: size * 0.075)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, achievement.fraction)))
                    .stroke(Tokens.ink, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                glyph(size * 0.3).foregroundStyle(Tokens.ink.opacity(0.7))
            case .locked:
                shape.fill(Tokens.ink.opacity(0.12))
                glyph(size * 0.34).foregroundStyle(Tokens.paper.opacity(0.85))
            }
        }
        .padding(Self.look(achievement) == .near ? size * 0.04 : 0)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func glyph(_ points: CGFloat) -> some View {
        Image(systemName: AchievementLook.glyph(achievement))
            .font(.system(size: points, weight: .black))
    }
}
