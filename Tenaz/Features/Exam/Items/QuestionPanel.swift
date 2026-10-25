import SwiftUI
import TenazCore

/// The right-hand column of reading and listening items: "Question 2 of 5", the question, options.
struct QuestionPanel: View {
    let runner: ExamRunner
    let questions: [ChoiceQuestion]

    private var index: Int { min(runner.draft.questionIndex, max(questions.count - 1, 0)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            if questions.count > 1 {
                HStack(spacing: Tokens.Space.xs) {
                    Text("Question \(index + 1) of \(questions.count)")
                        .font(Typography.labelBold)
                        .foregroundStyle(Tokens.brand)
                    Spacer()
                    QuestionDots(count: questions.count, current: index, answered: runner.draft.choices.map { $0 != nil })
                }
            }
            if questions.indices.contains(index) {
                Text(questions[index].q)
                    .font(Typography.displayM)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ExamOptionList(options: questions[index].options, selected: runner.draft.choices[safe: index] ?? nil,
                               choose: runner.choose)
            }
            if index > 0 {
                Button("Previous question", systemImage: "arrow.left", action: runner.previousQuestion)
                    .buttonStyle(.ink)
            }
        }
    }
}

/// Small flat dots: ink for answered questions, faint for open ones, larger for the current one.
struct QuestionDots: View {
    let count: Int
    let current: Int
    let answered: [Bool]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(Tokens.ink.opacity(answered[safe: i] == true ? 1 : (i == current ? 0.55 : 0.2)))
                    .frame(width: i == current ? 12 : 8, height: i == current ? 12 : 8)
            }
        }
        .accessibilityHidden(true)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
