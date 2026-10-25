import SwiftUI
import TenazCore

/// A text-only achievement row: the name, its progress right-aligned, optionally a thin 6 pt bar.
/// Click (or Space/Return) for the detail popover.
struct AchievementRow: View {
    let achievement: AchievementProgress
    var showsBar: Bool
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
                    Text(achievement.displayName)
                        .font(Typography.label)
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                    Spacer(minLength: Tokens.Space.s)
                    Text(AchievementLook.progressText(achievement))
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                        .lineLimit(1)
                }
                if showsBar {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Tokens.ink.opacity(0.15))
                            Capsule().fill(Tokens.ink)
                                .frame(width: max(6, proxy.size.width * min(1, achievement.fraction)))
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(.vertical, Tokens.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDetail, arrowEdge: .bottom) { AchievementDetail(achievement: achievement) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.displayName)
        .accessibilityValue(AchievementLook.progressText(achievement))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showDetail = true }
    }
}
