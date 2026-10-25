import SwiftUI
import TenazCore

/// Listening items: the audio card on the left (2 plays, transcript hidden unless speech failed),
/// and the reply options or the questions on the right.
struct ListeningItemView: View {
    let runner: ExamRunner
    let task: ExamTask

    private var isResponse: Bool { task.item?.type == .listenResponse }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.xl) {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                AudioCard(runner: runner, task: task, title: task.item?.title ?? "A speaker talks to you")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Group {
                if isResponse {
                    VStack(alignment: .leading, spacing: Tokens.Space.m) {
                        Text("Pick the best reply")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Tokens.ink)
                        ExamOptionList(options: task.item?.options ?? [], selected: runner.draft.choices.first ?? nil,
                                       choose: runner.choose)
                    }
                } else {
                    QuestionPanel(runner: runner, questions: task.item?.questions ?? [])
                }
            }
            .frame(width: 440, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
