import SwiftUI
import TenazCore

/// All 53 achievements (PLAN F9, research 11 §6.6). One hero: how many are earned, with the three
/// closest goals beside it. Below, the shelf in three sizes: earned (big, full colour), near (ring),
/// locked (small silhouettes).
struct AchievementsScreen: View {
    let achievements: [AchievementProgress]

    private var earned: [AchievementProgress] {
        achievements.filter(\.isUnlocked).sorted { ($0.unlockedAt ?? 0, $1.id) > ($1.unlockedAt ?? 0, $0.id) }
    }

    /// Locked, not secret, measurable: the nearest first.
    private var closest: [AchievementProgress] {
        Array(achievements
            .filter { !$0.isUnlocked && !$0.definition.hidden && $0.value != nil }
            .sorted { ($0.fraction, -$0.definition.threshold, $1.id) > ($1.fraction, -$1.definition.threshold, $0.id) }
            .prefix(3))
    }

    private var closestIds: Set<String> { Set(closest.map(\.id)) }

    private var near: [AchievementProgress] {
        achievements
            .filter { !$0.isUnlocked && AchievementStamp.look($0) == .near && !closestIds.contains($0.id) }
            .sorted { ($0.fraction, $1.id) > ($1.fraction, $0.id) }
    }

    private var locked: [AchievementProgress] {
        func rank(_ a: AchievementProgress) -> Int { a.definition.hidden ? 1 : 0 }
        return achievements
            .filter { !$0.isUnlocked && AchievementStamp.look($0) == .locked }
            .sorted { rank($0) != rank($1) ? rank($0) < rank($1) : $0.id < $1.id }
    }

    var body: some View {
        ProgressPage {
            hero
            if !earned.isEmpty {
                section("Earned") {
                    grid(earned, badge: 96, width: 132)
                }
            }
            if !near.isEmpty {
                section("On the way") {
                    VStack(spacing: 0) {
                        ForEach(Array(near.prefix(5).enumerated()), id: \.element.id) { index, item in
                            if index > 0 { ProgressRule() }
                            AchievementRow(achievement: item, showsBar: true)
                        }
                    }
                }
            }
            if !toFind.isEmpty {
                section("Still to find") {
                    stillToFind
                }
            }
        }
    }

    /// Locked, measurable and not secret: the ones with a number to chase.
    private var toFind: [AchievementProgress] {
        locked.filter { !$0.definition.hidden && $0.value != nil }
    }

    private var stillToFind: some View {
        let half = (toFind.count + 1) / 2
        let columns = [Array(toFind.prefix(half)), Array(toFind.dropFirst(half))]
        let soon = locked.filter { !$0.definition.hidden && $0.value == nil }.count
        let secret = locked.filter(\.definition.hidden).count
        return VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(alignment: .top, spacing: Tokens.Space.xl) {
                ForEach(0..<2, id: \.self) { column in
                    VStack(spacing: 0) {
                        ForEach(Array(columns[column].enumerated()), id: \.element.id) { index, item in
                            if index > 0 { ProgressRule() }
                            AchievementRow(achievement: item, showsBar: false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            Text("Plus \(soon) that unlock once speaking and writing are built · \(secret) secret")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Tokens.brand)
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: Tokens.Space.xxl) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(earned.count)")
                    .font(Typography.numberHero)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.vertical, -26)
                Text("achievements earned")
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                Text("\(achievements.count - earned.count) to go. Earned by learning, never by just opening the app.")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Tokens.Space.xs)
            }
            .frame(width: 330, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(earned.count) of \(achievements.count) achievements earned")
            if !closest.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Closest to unlock")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                        .padding(.bottom, 2)
                    ForEach(Array(closest.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { ProgressRule() }
                        ClosestCard(achievement: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Tokens.Space.l)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            ProgressSectionLabel(title)
            content()
        }
    }

    private func grid(_ items: [AchievementProgress], badge: CGFloat, width: CGFloat) -> some View {
        WordWrapLayout(spacing: Tokens.Space.xs, lineSpacing: Tokens.Space.l) {
            ForEach(items) { AchievementTile(achievement: $0, badge: badge).frame(width: width) }
        }
    }
}
