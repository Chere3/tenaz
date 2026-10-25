import SwiftUI
import TenazCore

/// The end of a session on `.good`: the title is the hero, then what was earned as three plain
/// numbers, the daily minimum as one line, and one next step.
struct ReviewDoneView: View {
    let summary: ReviewSummary
    let actions: ReviewActions

    private var needsSentence: Bool { summary.correctToday >= StreakEngine.minCorrectRetrievals && summary.productionsToday < StreakEngine.minProductions }

    private var title: String {
        if summary.answered == 0 { return "See you soon" }
        if summary.accuracy >= 0.9 { return "Brilliant!" }
        if summary.accuracy >= 0.7 { return "Nice work!" }
        return "Good practice!"
    }

    private var line: String {
        if summary.stageAdvanced { return "I grew! I'm a \(summary.stageName.lowercased()) now." }
        if summary.dayQualified { return "Daily minimum done. I'm full and happy!" }
        if needsSentence { return "Words done! One sentence and the day counts." }
        if summary.comingBack > 0 { return "\(summary.comingBack) words come back later today. See you then!" }
        return summary.answered == 0 ? "Come back when you have a minute." : "Thanks for feeding me. See you later!"
    }

    /// "10 of 10 words · 0 of 1 sentence", with a check once each part is met.
    private var minimum: String {
        let words = min(summary.correctToday, StreakEngine.minCorrectRetrievals)
        let sentences = min(summary.productionsToday, StreakEngine.minProductions)
        let sentenceWord = StreakEngine.minProductions == 1 ? "sentence" : "sentences"
        return "Today: \(words) of \(StreakEngine.minCorrectRetrievals) words · \(sentences) of \(StreakEngine.minProductions) \(sentenceWord)"
    }

    var body: some View {
        ReviewPause(hero: title, heroFont: Typography.display(80), line: line,
                    primaryTitle: needsSentence ? "Write one sentence" : "Back to Today",
                    primary: needsSentence ? actions.write : actions.home,
                    secondaryTitle: needsSentence ? "Later" : nil, secondary: actions.home)
        {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                Text(statsLine)
                    .font(Typography.body)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
                // The remaining task is already in `line` when a sentence is missing.
                if !needsSentence {
                    Label(minimum, systemImage: summary.dayQualified ? "checkmark" : "circle.dashed")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.ink)
                }
            }
        }
    }

    /// "14 answers · 86% right · best run 8 · +156 xp" on one line.
    private var statsLine: String {
        let percent = summary.accuracy.formatted(.percent.precision(.fractionLength(0)))
        let xp = summary.leveledUp ? "+\(summary.xp) xp · level \(summary.level)!" : "+\(summary.xp) xp"
        return "\(summary.answered) answers · \(percent) right · best run \(summary.bestCombo) · \(xp)"
    }
}
