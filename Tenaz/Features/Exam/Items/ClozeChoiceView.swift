import SwiftUI
import TenazCore

/// Vocabulary probe and grammar items: one sentence with a gap, four options in a 2 × 2 grid.
/// The picked word appears in the gap so the learner reads the whole sentence before going on.
struct ClozeChoiceView: View {
    let runner: ExamRunner
    let task: ExamTask

    private var parts: (sentence: String, options: [String]) {
        switch task.content {
        case let .vocab(entry, options, _): (entry.cloze, options)
        case let .item(item): (item.sentence ?? "", item.options ?? [])
        }
    }

    var body: some View {
        let (sentence, options) = parts
        let picked = runner.draft.choices.first.flatMap { $0 }.flatMap { options[safe: $0] }
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            ClozeSentence(sentence: sentence, filled: picked)
                .frame(maxWidth: .infinity, alignment: .leading)
            ExamOptionList(options: options, selected: runner.draft.choices.first ?? nil, columns: 2, choose: runner.choose)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The sentence with its `____` drawn as a faint blank, or the picked word underlined in it.
struct ClozeSentence: View {
    let sentence: String
    let filled: String?

    var body: some View {
        let pieces = sentence.components(separatedBy: "____")
        let before = Text(pieces.first ?? "")
        let after = Text(pieces.count > 1 ? pieces[1...].joined(separator: "____") : "")
        let gap = Text(filled ?? "________")
            .foregroundStyle(filled == nil ? Tokens.ink.opacity(0.28) : Tokens.ink)
            .underline(filled != nil, color: Tokens.ink)
        Text("\(before)\(gap)\(after)")
            .font(Typography.prompt)
            .foregroundStyle(Tokens.ink)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(sentence.replacing("____", with: filled ?? "blank"))
    }
}
