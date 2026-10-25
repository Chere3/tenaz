import SwiftUI

/// Bottom strip: the honest integrity line on the left, the one primary action on the right.
struct ExamFooter: View {
    let runner: ExamRunner
    let escHold: Double
    let onLeave: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.l) {
            if runner.examMode {
                HStack(spacing: Tokens.Space.s) {
                    Label("Exam Mode", systemImage: "lock.fill")
                    Text("·")
                    Label(runner.witness.title, systemImage: runner.witness.systemImage)
                    Text("·")
                    EscHoldHint(progress: escHold)
                }
                .font(Typography.label)
                .foregroundStyle(Tokens.ink.opacity(0.72))
            } else {
                Label("Answers save as you go", systemImage: "tray.and.arrow.down.fill")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                Button("Leave", systemImage: "xmark", action: onLeave)
                    .buttonStyle(.ink)
            }
            if let problem = runner.saveProblem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.wrong)
            }
            Spacer(minLength: Tokens.Space.m)
            ExamPrimaryButton(runner: runner)
                .frame(width: 300)
        }
    }
}
