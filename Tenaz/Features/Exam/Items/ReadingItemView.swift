import SwiftUI
import TenazCore

/// Read in Daily Life / Academic Passage: the text on the left, one question at a time on the right.
struct ReadingItemView: View {
    let runner: ExamRunner
    let task: ExamTask

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.xl) {
            PassageCard(title: task.item?.title, text: task.item?.text ?? "")
                .frame(maxWidth: 620, maxHeight: .infinity, alignment: .top)
            Spacer(minLength: 0)
            QuestionPanel(runner: runner, questions: task.item?.questions ?? [])
                .frame(maxWidth: 520, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
