import SwiftUI
import TenazCore

/// Poster mode (F1, Full Bleed): the whole panel is one flood (yellow = your turn, mint = right, coral =
/// wrong). One word, huge; Tena cropped by the bottom edge; the answer on a paper sheet; the escape
/// ladder always visible at the top-left and bottom.
struct WordOverlayView: View {
    @Bindable var model: OverlayModel
    let deadline: Date
    var stage: TenaStage = .juvenile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isWrong: Bool {
        if case .wrong = model.phase { return true }
        return false
    }

    /// The right-hand column Tena owns: the rule and footer end before her.
    private static let tenaColumn: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OverlayTopBar(index: model.index, total: model.total, skipCost: model.skipCost, deadline: deadline) { model.escape(.skip) }
            if case let .done(correct, total, xp) = model.phase {
                Spacer(minLength: 0)
                OverlayDoneStamp(correct: correct, total: total, xp: xp)
                Spacer(minLength: 0)
            } else if let item = model.current {
                if isWrong { Spacer().frame(height: Tokens.Space.xxl) } else { Spacer(minLength: Tokens.Space.m) }
                VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                    if !isWrong {
                        OverlayKicker(type: item.prompt.type)
                        OverlayPrompt(prompt: item.prompt)
                            .padding(.vertical, -28)
                            .id(model.index)
                            .transition(reduceMotion ? .opacity : .scale(scale: 1.08).combined(with: .opacity))
                        OverlayHint(hint: item.prompt.hint, shown: model.showHint, toggle: model.toggleHint)
                            .padding(.leading, model.showHint ? 0 : -Tokens.Space.s)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: Tokens.Space.m)
                OverlayAnswerArea(model: model, item: item)
                    .frame(maxWidth: 600, alignment: .leading)
                Spacer(minLength: Tokens.Space.l)
            }
            Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: 1)
                .padding(.bottom, Tokens.Space.xs)
                .padding(.trailing, Self.tenaColumn)
            OverlayFooter(snoozesLeft: model.snoozesLeft, snooze: { model.escape(.snooze) }, meeting: { model.escape(.meeting) })
                .padding(.trailing, Self.tenaColumn)
        }
        .padding(.horizontal, Tokens.Space.xxl)
        .padding(.vertical, Tokens.Space.l)
        .background(alignment: .bottomTrailing) {
            OverlayTena(phase: model.phase, stage: stage, size: 400)
                .padding(.trailing, Tokens.Space.m)
                .offset(y: 110)
        }
        .background {
            if case .asking = model.phase {} else if !isWrong { OverlayRays(center: UnitPoint(x: 0.82, y: 0.9)) }
        }
        .overlayCard(model.phase, radius: 32)
        .animation(Motion.animation(.slam, reduceMotion: reduceMotion), value: model.index)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tenaz word overlay")
    }
}
