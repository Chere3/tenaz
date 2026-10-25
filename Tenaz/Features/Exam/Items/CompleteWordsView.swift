import SwiftUI
import TenazCore

/// Complete the Words: the paragraph flows like normal text with a small field inside each cut
/// word. Tab and Shift-Tab move between gaps; Return hands the paragraph in.
struct CompleteWordsView: View {
    @Bindable var runner: ExamRunner
    let task: ExamTask
    @State private var focusedGap = 0

    private enum Piece: Identifiable {
        case word(Int, String)
        /// The gap, plus any punctuation glued to it ("wor{{k}}." -> trailing ".").
        case gap(Int, WordGap, trailing: String)
        var id: String {
            switch self {
            case let .word(i, _): "w\(i)"
            case let .gap(i, _, _): "g\(i)"
            }
        }
    }

    private var pieces: [Piece] {
        var result: [Piece] = []
        var gapIndex = 0
        var n = 0
        var pendingGap: WordGap?
        func flushGap(trailing: String) {
            guard let gap = pendingGap else { return }
            result.append(.gap(gapIndex, gap, trailing: trailing))
            gapIndex += 1
            pendingGap = nil
        }
        for segment in CompleteWordsParser.parse(task.item?.passage ?? "") {
            switch segment {
            case let .text(text):
                var rest = Substring(text)
                if pendingGap != nil {
                    let glue = rest.prefix { $0 != " " }
                    flushGap(trailing: String(glue))
                    rest = rest.dropFirst(glue.count)
                }
                for word in rest.split(separator: " ", omittingEmptySubsequences: true) {
                    result.append(.word(n, String(word)))
                    n += 1
                }
            case let .gap(gap):
                flushGap(trailing: "")
                pendingGap = gap
            }
        }
        flushGap(trailing: "")
        return result
    }

    private var filledCount: Int { runner.draft.gaps.count { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            FlowLayout(spacing: 0, lineSpacing: 18) {
                ForEach(pieces) { piece in
                    switch piece {
                    case let .word(_, word):
                        Text(word + " ")
                            .font(Self.font)
                            .foregroundStyle(Tokens.ink)
                    case let .gap(i, gap, trailing):
                        GapWord(visible: gap.visible, hiddenLength: gap.hidden.count, trailing: trailing, text: runner.slot(\.gaps, i),
                                isFocused: focusedGap == i, actions: actions(for: i))
                    }
                }
            }
            .padding(Tokens.Space.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .examSheet()
            HStack(spacing: Tokens.Space.s) {
                KeyCap("Tab")
                Text("next gap")
                KeyCap("⇧ Tab")
                Text("back")
                Spacer()
                Text("\(filledCount) of \(runner.draft.gaps.count) gaps filled")
                    .font(Typography.numeric(14))
            }
            .font(Typography.label)
            .foregroundStyle(Tokens.brand)
            Spacer(minLength: Tokens.Space.m)
        }
        .frame(maxWidth: 1040, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static let font = Font.system(size: 26, weight: .regular, design: .rounded)

    private func actions(for i: Int) -> ExamTextActions {
        let count = runner.draft.gaps.count
        let filled = filledCount
        return ExamTextActions(
            // Return moves on to the next gap; on the last gap (or with every gap filled) it hands in.
            submit: { if i < count - 1, filled < count { focusedGap = i + 1 } else { runner.next() } },
            tab: { focusedGap = min(i + 1, count - 1) },
            backtab: { focusedGap = max(i - 1, 0) },
            focus: { focusedGap = i },
            edit: runner.recordTyping,
            pasteBlocked: runner.pasteBlocked)
    }
}

/// "tech" + a field sized for the missing letters, underlined in ink.
private struct GapWord: View {
    let visible: String
    let hiddenLength: Int
    let trailing: String
    @Binding var text: String
    let isFocused: Bool
    let actions: ExamTextActions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(visible)
                .font(CompleteWordsView.font)
                .foregroundStyle(Tokens.ink)
            ExamTextField(text: $text, multiline: false, fontSize: 26, weight: .regular, isFocused: isFocused, actions: actions)
                .frame(width: CGFloat(hiddenLength) * 14 + 6, height: 34)
                .alignmentGuide(.firstTextBaseline) { $0[.top] + 28 }
                .overlay(alignment: .bottom) {
                    Capsule().fill(isFocused ? Tokens.ink : Tokens.ink.opacity(0.3)).frame(height: isFocused ? 3 : 2)
                }
            Text(trailing + " ")
                .font(CompleteWordsView.font)
                .foregroundStyle(Tokens.ink)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Finish the word starting \(visible)")
    }
}
