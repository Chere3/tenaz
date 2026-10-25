import SwiftUI

/// The Exam Mode panel content: the runner, with the leave confirmation on top after Esc is held.
struct ExamModeRoot: View {
    let controller: ExamModeController
    let runner: ExamRunner

    var body: some View {
        ZStack {
            ExamRunnerView(runner: runner, escHold: controller.escProgress, notched: true)
                .disabled(controller.confirmingLeave)
            if controller.keyboardLost && !controller.confirmingLeave {
                VStack {
                    Button(action: controller.regainKeyboard) {
                        Label("Click here to type", systemImage: "keyboard")
                    }
                    .buttonStyle(.fat)
                    .frame(width: 320)
                    .padding(.top, 210)
                    Spacer()
                }
            }
            if controller.confirmingLeave {
                Tokens.ink.opacity(0.45).ignoresSafeArea().clipShape(NotchedPage())
                LeaveConfirmCard(keepGoing: { controller.confirmingLeave = false }, leave: controller.leave)
            }
        }
    }
}

/// "Leave the test?" with the safe choice as the primary action.
private struct LeaveConfirmCard: View {
    let keepGoing: () -> Void
    let leave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            MisprintText("Leave the test?", font: Typography.displayM)
            Text("This attempt won't count. Your answers stay saved for your own review, and you can start again any time.")
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Space.m) {
                Button("Leave and void it", systemImage: "xmark", action: leave)
                    .buttonStyle(InkTextButtonStyle(tint: Tokens.wrong))
                Spacer()
                Button(action: keepGoing) {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Keep going")
                        KeyCap("Return", fill: Tokens.accent)
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .frame(width: 260)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 560)
        .sticker(Tokens.paper, radius: Tokens.Radius.card, depth: 6)
    }
}
