import SwiftUI
import TenazCore

/// The answer part of the card: options or the typed field (on a paper sheet) while asking, then the verdict.
struct OverlayAnswerArea: View {
    @Bindable var model: OverlayModel
    let item: SessionItem
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Tokens.Space.xs : Tokens.Space.m) {
            if item.prompt.type == .recognition {
                OverlayChoiceGrid(options: item.prompt.options, picked: picked, correct: picked == nil ? nil : item.prompt.correctOption,
                                  compact: compact) { model.choose($0) }
            } else if model.phase == .asking {
                AnswerField(text: $model.text, prompt: compact ? "Type it" : "Type the English", allowsPaste: false) { model.submit() }
                    .onChange(of: model.text) { _, new in model.textChanged(new) }
                    .padding(.horizontal, compact ? Tokens.Space.s : Tokens.Space.l)
                    .padding(.vertical, compact ? Tokens.Space.xs : Tokens.Space.m)
                    .background {
                        RoundedRectangle(cornerRadius: compact ? 18 : Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper)
                    }
            }
            OverlayVerdict(phase: model.phase, compact: compact, next: { model.submit() })
        }
    }

    /// The option they chose, once answered (recognition).
    private var picked: Int? {
        switch model.phase {
        case .correct: item.prompt.correctOption
        case let .wrong(_, given): item.prompt.options.firstIndex(of: given)
        default: nil
        }
    }
}
