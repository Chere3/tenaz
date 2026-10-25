import SwiftUI

/// A sentence with its `____` drawn as an ink bar, like the review question.
struct OverlayGapSentence: View {
    let sentence: String
    var compact = false

    var body: some View {
        let parts = sentence.components(separatedBy: "____")
        let gap = Text(compact ? "\u{2003}\u{2003}\u{2003}" : "\u{2003}\u{2003}\u{2003}\u{2003}").underline(true, color: Tokens.ink)
        let line = parts.enumerated().reduce(Text("")) { acc, pair in
            let piece = Text(pair.element)
            return pair.offset == 0 ? Text("\(acc)\(piece)") : Text("\(acc)\(gap)\(piece)")
        }
        line
            .font(Typography.display(compact ? 22 : 64, weight: 800))
            .foregroundStyle(Tokens.ink)
            .lineSpacing(compact ? 1 : 4)
            .lineLimit(3)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }
}
