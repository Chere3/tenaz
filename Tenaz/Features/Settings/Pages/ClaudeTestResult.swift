import SwiftUI

/// The line next to "Test connection".
struct ClaudeTestResult: View {
    let state: ClaudeTestState

    var body: some View {
        switch state {
        case .idle:
            Text("Makes one small call.").font(Typography.label).foregroundStyle(Tokens.brand)
        case .running:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Asking Claude…").font(Typography.label).foregroundStyle(Tokens.brand)
            }
        case let .ok(text):
            Label(text, systemImage: "checkmark.circle.fill").font(Typography.labelBold).foregroundStyle(Tokens.correct)
        case let .failed(text):
            Label(text, systemImage: "xmark.circle.fill").font(Typography.labelBold).foregroundStyle(Tokens.wrong).lineLimit(2)
        }
    }
}
