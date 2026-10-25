import SwiftUI
import TenazCore

/// Listen & Repeat and Take an Interview. The default path is typing ("Type what you would say");
/// the microphone is used only after the learner presses "Use microphone" and macOS allows it.
struct SpeakingItemView: View {
    @Bindable var runner: ExamRunner
    let task: ExamTask

    private var isInterview: Bool { task.item?.type == .interview }
    private var questions: [String] { task.item?.interviewQuestions ?? [] }
    private var q: Int { min(runner.draft.questionIndex, max(questions.count - 1, 0)) }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.xl) {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                if isInterview {
                    InterviewQuestionCard(runner: runner, topic: task.item?.topic, questions: questions, index: q)
                } else {
                    AudioCard(runner: runner, task: task, title: "Listen, then say it back")
                }
                Spacer(minLength: 0)
            }
            .frame(width: 430)
            .frame(maxHeight: .infinity, alignment: .top)
            if isInterview, runner.draft.texts.indices.contains(q) {
                SpeakingAnswerPanel(runner: runner, task: task, text: runner.slot(\.texts, q), multiline: true)
            } else {
                SpeakingAnswerPanel(runner: runner, task: task, text: $runner.draft.text, multiline: false)
            }
        }
    }
}

/// "Question 2 of 4" and the interviewer's question, with a play key to hear it.
private struct InterviewQuestionCard: View {
    let runner: ExamRunner
    let topic: String?
    let questions: [String]
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack {
                Text("Question \(index + 1) of \(questions.count)")
                    .font(Typography.labelBold).foregroundStyle(Tokens.brand)
                Spacer()
                QuestionDots(count: questions.count, current: index, answered: runner.draft.texts.map { !$0.isEmpty })
            }
            if let topic { Label(topic, systemImage: "person.wave.2.fill").font(Typography.labelBold).foregroundStyle(Tokens.brand) }
            Text(questions[safe: index] ?? "")
                .font(Typography.display(34, weight: 800))
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(runner.isPlaying ? "Playing…" : "Hear the question", systemImage: "speaker.wave.2.fill", action: runner.play)
                .buttonStyle(.ink)
                .disabled(runner.isPlaying || runner.playsLeft == 0)
            Text("About 2 minutes: answer, give a reason, add an example.")
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
