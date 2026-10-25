import SwiftUI

/// The minimum viable day drawn, not written: ten cells for correct words and one pencil for the
/// sentence. Turns into a green "Day done" stamp once both are filled.
struct DailyMinimumStrip: View {
    let correct: Int
    let productions: Int
    let minimumCorrect: Int
    let minimumProductions: Int

    private var wordsDone: Bool { correct >= minimumCorrect }
    private var sentenceDone: Bool { productions >= minimumProductions }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Tokens.Space.xs) {
                Text("Daily minimum")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                Spacer(minLength: 0)
                if wordsDone, sentenceDone {
                    Chip("Day done", state: .done)
                }
            }
            HStack(spacing: Tokens.Space.s) {
                MeterCells(fraction: Double(min(correct, minimumCorrect)) / Double(max(minimumCorrect, 1)), fill: Tokens.correct,
                           cells: minimumCorrect)
                    .frame(height: 16)
                Image(systemName: sentenceDone ? "pencil.circle.fill" : "pencil.circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(sentenceDone ? Tokens.correct : Tokens.ink)
            }
            Text("\(min(correct, minimumCorrect)) of \(minimumCorrect) words · \(min(productions, minimumProductions)) of \(minimumProductions) sentence")
                .font(Typography.numeric(13))
                .foregroundStyle(Tokens.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily minimum")
        .accessibilityValue("\(correct) of \(minimumCorrect) words, \(productions) of \(minimumProductions) sentence")
    }
}
