import SwiftUI

/// The single fat button of the exam screen. Return triggers it, except in text tasks: single-line
/// fields submit with Return themselves, and long answers use Command-Return so Return can start
/// a new line.
struct ExamPrimaryButton: View {
    let runner: ExamRunner

    private enum Shortcut { case returnKey, commandReturn, none }

    private var title: String {
        switch runner.phase {
        case .intro: runner.resumed && runner.session.sectionPosition > 0 ? "Continue" : "Start section"
        case .meetingPause: "Resume"
        case .finished, .voided: "Saving"
        case .task:
            if needsAnswer { runner.kind == .buildSentence ? "Place a piece" : "Pick an answer" }
            else if let task = runner.task, runner.draft.questionIndex < runner.questionCount(task) - 1 { "Next question" }
            else if runner.kind?.usesLongText == true { "Hand it in" }
            else { "Next" }
        }
    }

    private var shortcut: Shortcut {
        guard runner.phase == .task else { return .returnKey }
        switch runner.kind {
        case .writing, .interview: return .commandReturn
        case .completeWords, .listenRepeat: return .none
        default: return .returnKey
        }
    }

    /// Option tasks and Build a Sentence need a pick first, so a stray Return never skips a task.
    private var needsAnswer: Bool {
        guard runner.phase == .task, let kind = runner.kind else { return false }
        if kind.hasOptions { return (runner.draft.choices[safe: runner.draft.questionIndex] ?? nil) == nil }
        if kind == .buildSentence { return runner.draft.order.isEmpty }
        return false
    }

    private var keyLabel: String { shortcut == .commandReturn ? "⌘ Return" : "Return" }

    var body: some View {
        let button = Button(action: act) {
            HStack(spacing: Tokens.Space.s) {
                Text(title)
                KeyCap(keyLabel, fill: Tokens.accent)
            }
        }
        .buttonStyle(.fat)
        .disabled(runner.phase == .finished || runner.phase == .voided || needsAnswer)
        switch shortcut {
        case .returnKey: button.keyboardShortcut(.defaultAction)
        case .commandReturn: button.keyboardShortcut(.return, modifiers: .command)
        case .none: button
        }
    }

    private func act() {
        switch runner.phase {
        case .intro, .meetingPause: runner.startSection()
        case .task: runner.next()
        case .finished, .voided: break
        }
    }
}
