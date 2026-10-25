import SwiftUI
import TenazCore

/// Sticker mode (F1): a small flat pill-shaped card in the bottom-right corner, no sound. It carries
/// the same flood as the poster. Same batch, same hatches.
struct WordStickerView: View {
    @Bindable var model: OverlayModel
    let deadline: Date

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            OverlayTopBar(index: model.index, total: model.total, skipCost: model.skipCost, deadline: deadline, compact: true) {
                model.escape(.skip)
            }
            if case let .done(correct, total, xp) = model.phase {
                Spacer(minLength: 0)
                OverlayDoneStamp(correct: correct, total: total, xp: xp, compact: true)
                Spacer(minLength: 0)
            } else if let item = model.current {
                HStack(alignment: .firstTextBaseline) {
                    OverlayKicker(type: item.prompt.type, compact: true)
                    Spacer()
                    OverlayHint(hint: item.prompt.hint, shown: model.showHint, compact: true, toggle: model.toggleHint)
                }
                if case .wrong = model.phase {} else {
                    OverlayPrompt(prompt: item.prompt, compact: true)
                }
                Spacer(minLength: 0)
                OverlayAnswerArea(model: model, item: item, compact: true)
            }
            Spacer(minLength: 0)
            OverlayFooter(snoozesLeft: model.snoozesLeft, compact: true, snooze: { model.escape(.snooze) }, meeting: { model.escape(.meeting) })
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.m)
        .overlayCard(model.phase, radius: 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tenaz word sticker")
    }
}
