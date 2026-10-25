import SwiftUI
import TenazCore

/// The task on screen, chosen by its kind. Owns the keyboard for option tasks: 1-4 pick,
/// Space plays audio, and in Build a Sentence the numbers place pieces and Delete takes one back.
struct ExamTaskView: View {
    @Bindable var runner: ExamRunner
    @FocusState private var keyFocus: Bool

    var body: some View {
        if let task = runner.task, let kind = runner.kind {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                if kind == .completeWords || kind == .buildSentence {
                    Text(kind.instruction)
                        .font(Typography.title)
                        .foregroundStyle(Tokens.brand)
                }
                content(task, kind)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .focusable(!kind.hasTextField)
            .focused($keyFocus)
            .focusEffectDisabled()
            .onKeyPress(phases: .down) { press in handle(press, kind: kind, task: task) }
            .onAppear { keyFocus = !kind.hasTextField }
        }
    }

    @ViewBuilder
    private func content(_ task: ExamTask, _ kind: ExamTaskKind) -> some View {
        switch kind {
        case .vocab, .grammar: ClozeChoiceView(runner: runner, task: task)
        case .reading: ReadingItemView(runner: runner, task: task)
        case .listenResponse, .listening: ListeningItemView(runner: runner, task: task)
        case .completeWords: CompleteWordsView(runner: runner, task: task)
        case .buildSentence: BuildSentenceView(runner: runner, task: task)
        case .writing: WritingItemView(runner: runner, task: task)
        case .listenRepeat, .interview: SpeakingItemView(runner: runner, task: task)
        }
    }

    private func handle(_ press: KeyPress, kind: ExamTaskKind, task: ExamTask) -> KeyPress.Result {
        if press.key == .space, kind == .listening || kind == .listenResponse {
            runner.play()
            return .handled
        }
        guard let digit = Int(press.characters), digit >= 1 else {
            if kind == .buildSentence, press.key == .delete, !runner.draft.order.isEmpty {
                runner.draft.order.removeLast()
                return .handled
            }
            if press.key == .leftArrow, kind.hasOptions {
                runner.previousQuestion()
                return .handled
            }
            return .ignored
        }
        if kind == .buildSentence {
            let index = digit - 1
            if (task.item?.chunks ?? []).indices.contains(index), !runner.draft.order.contains(index) {
                runner.draft.order.append(index)
            }
            return .handled
        }
        guard kind.hasOptions else { return .ignored }
        runner.choose(digit - 1)
        return .handled
    }
}

extension ExamTaskKind {
    /// Tasks whose keyboard belongs to a text field.
    var hasTextField: Bool { [.completeWords, .writing, .listenRepeat, .interview].contains(self) }
}
