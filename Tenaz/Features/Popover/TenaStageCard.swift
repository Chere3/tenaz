import SwiftUI

/// The top of the popover: Tena big, cropped by the popover's left edge, and the one hero on the right.
/// The hero follows the primary action, so the screen never offers two different next steps.
struct TenaStageCard: View {
    let state: PopoverState

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            TenaView(mood: state.mood, stage: state.stage, size: 220)
                .offset(x: -62, y: -6)
                .frame(width: 150, height: 160, alignment: .topLeading)
                .clipped()
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
