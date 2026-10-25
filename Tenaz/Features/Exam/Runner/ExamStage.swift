import SwiftUI

/// The middle of the exam screen, by phase.
struct ExamStage: View {
    @Bindable var runner: ExamRunner

    var body: some View {
        switch runner.phase {
        case .intro:
            SectionIntroView(runner: runner)
        case .task:
            ExamTaskView(runner: runner)
                .id(runner.task?.id)
        case .meetingPause:
            ExamMessageView(title: "Paused for your meeting", systemImage: "phone.fill",
                            message: "The timer stopped. Nothing was flagged. Come back when the call ends.")
        case .finished:
            ExamMessageView(title: "All done", systemImage: "checkmark.seal.fill",
                            message: "Your answers are saved. Opening your results…")
        case .voided:
            ExamMessageView(title: "You left the test", systemImage: "xmark.circle.fill",
                            message: "This attempt won't count. You can take it again any time.")
        }
    }
}
