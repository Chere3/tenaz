import SwiftUI

/// The bottom strip on Today: streak, level and band as plain text under a thin ink rule.
struct HomeStats: View {
    let summary: TodaySummary
    var showLevel: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Rectangle()
                .fill(Tokens.ink.opacity(0.18))
                .frame(height: 1.5)
            // Roomy like the mockup; tighter when the window is at its minimum width.
            ViewThatFits(in: .horizontal) {
                row(spacing: 48)
                row(spacing: 24)
            }
        }
    }

    private func row(spacing: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            if !isFresh {
                HomeStat(value: "\(summary.streakDays)", label: "day streak")
                    .accessibilityLabel("Streak")
                    .accessibilityValue("\(summary.streakDays) days, best \(summary.bestStreak)")
                HomeStat(value: "\(summary.level)", label: "level · \(summary.xpIntoLevel)/\(summary.xpForLevel) xp")
                    .accessibilityLabel("Level \(summary.level)")
                    .accessibilityValue("\(summary.xpIntoLevel) of \(summary.xpForLevel) XP to the next level")
            }
            Button(action: showLevel) {
                HomeStat(value: bandValue, label: bandLabel)
            }
            .buttonStyle(.plain)
            .help(summary.band == nil ? "Find my level" : "See exams")
            .accessibilityLabel(summary.band == nil ? "Band not measured yet" : "Band \(bandValue)")
            .accessibilityValue(bandLabel)
            Spacer(minLength: 0)
        }
    }

    /// First run: zero streak and level 1 with no xp is noise next to the one thing to do.
    private var isFresh: Bool { summary.streakDays == 0 && summary.level == 1 && summary.xpIntoLevel == 0 }

    private var bandValue: String {
        summary.band.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? summary.levelLabel
    }

    private var bandLabel: String {
        guard summary.band != nil else { return "start estimate" }
        return summary.catchingUp ? "band · \(summary.levelLabel) · catching up" : "band · \(summary.levelLabel)"
    }
}

private struct HomeStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.display(38))
                .foregroundStyle(Tokens.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
    }
}
