import SwiftUI
import TenazCore

/// Live local checks: a word meter that fills to the target, and four plain checks with a glyph
/// each (a tick when met), no chips.
struct GateChecklist: View {
    let checks: GateCheckResult

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.s) {
                GateWordMeter(words: checks.words, minWords: checks.minWords, target: checks.targetWords)
                    .frame(height: 18)
                Text("\(checks.words) / \(checks.targetWords) words")
                    .font(Typography.numeric(16))
                    .foregroundStyle(Tokens.ink)
                    .frame(minWidth: 112, alignment: .trailing)
                    .contentTransition(.numericText())
            }
            HStack(spacing: Tokens.Space.l) {
                check("\(checks.minWords)+ words", checks.lengthOK)
                check("In English", checks.englishOK)
                if let chunk = checks.chunk {
                    check("Uses “\(chunk)”", checks.chunkPresent)
                }
                check("Varied words", checks.varietyOK)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func check(_ title: String, _ done: Bool) -> some View {
        Label(title, systemImage: done ? "checkmark.circle.fill" : "circle")
            .font(Typography.labelBold)
            .foregroundStyle(Tokens.ink.opacity(done ? 1 : 0.65))
            .accessibilityValue(done ? "done" : "not yet")
    }
}
