import SwiftUI

/// The top of the popover: Tena cropped only by the popover's left edge, and the one hero on the right.
/// The hero follows the primary action, so the screen never offers two different next steps.
struct TenaStageCard: View {
    let state: PopoverState

    /// Her frame side and leading offset in the 150 pt box (the box starts on the window's left edge):
    /// 166 pt and 26 pt past that edge, so the edge takes part of her near gill fan. She moves in when the
    /// edge would reach her head (8 pt clear), and shrinks when her far gills would come within 16 pt of
    /// the hero text beside the box.
    private var fit: (size: CGFloat, x: CGFloat) {
        let ink = TenaInk.bounds(stage: state.stage, mood: state.mood, size: 166, word: state.dueWord)
        let head = TenaRig(mood: state.mood, stage: state.stage, time: 0, size: 166, word: state.dueWord).headFrame?.minX ?? 0.3
        let reach: CGFloat = 150 - 16
        var size: CGFloat = 166
        if -26 + ink.maxX * size > reach { size = (reach + 26) / ink.maxX }
        if -26 + head * size >= 8 { return (size, -26) }
        size = min(size, (reach - 8) / (ink.maxX - head))
        return (size, 8 - head * size)
    }

    var body: some View {
        let fit = fit
        HStack(alignment: .center, spacing: 0) {
            // Whole inside the card, so the popover's left window edge is her only crop (it takes
            // part of the near gill fan, never her head); no inner container edge cuts through her body.
            TenaView(mood: state.mood, stage: state.stage, size: fit.size, word: state.dueWord)
                .offset(x: fit.x, y: -3)
                .frame(width: 150, height: 160, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 2) {
                hero
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.line) Stage \(state.stage.title).")
    }

    @ViewBuilder private var hero: some View {
        switch state.primary {
        case let .placement(minutes, _):
            Text("\(minutes) min")
                .font(Typography.display(64))
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("one test, then your words")
                .font(Typography.textButton)
                .foregroundStyle(Tokens.ink)
        case .review, .comeBack:
            if state.dueCount > 0 {
                Text("\(state.dueCount)")
                    .font(Typography.display(120))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.vertical, -16)
                Text(state.dueCount == 1 ? "word is waiting" : "words are waiting")
                    .font(Typography.textButton)
                    .foregroundStyle(Tokens.ink)
            } else {
                done
            }
        case .allDone:
            done
        }
    }

    @ViewBuilder private var done: some View {
        Text("Done")
            .font(Typography.display(72))
            .foregroundStyle(Tokens.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        Text("Nothing is due")
            .font(Typography.textButton)
            .foregroundStyle(Tokens.ink)
    }
}
