import SwiftUI

/// Why an exam can't start right now, with "I'm free, start anyway" when only the calendar blocks it.
struct ExamProblemRow: View {
    let problem: String
    var startAnyway: (() -> Void)?

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.wrong)
                .fixedSize(horizontal: false, vertical: true)
            if let startAnyway {
                Spacer(minLength: Tokens.Space.s)
                Button("I'm free, start anyway", systemImage: "play.fill", action: startAnyway)
                    .buttonStyle(InkTextButtonStyle(tint: Tokens.ink))
                    .help("Not a real meeting (a time block, a reminder). The exam ignores the calendar for this attempt.")
            }
        }
    }
}
