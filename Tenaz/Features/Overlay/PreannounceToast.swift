import SwiftUI

/// The 20-second warning before an overlay (F1, R5): never key, never steals focus. "Not now"
/// snoozes 15 minutes for free. A flat yellow pill: your turn is coming.
struct PreannounceToast: View {
    let deadline: Date
    let notNow: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            TenaView(mood: .curious, stage: .juvenile, size: 62)
            VStack(alignment: .leading, spacing: 2) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(deadline.timeIntervalSince(context.date).rounded(.up)))
                    Text("3 words in \(left) s")
                        .font(Typography.display(22))
                        .foregroundStyle(Tokens.ink)
                        .contentTransition(.numericText(countsDown: true))
                }
                Text("Finish your sentence first.")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
            Spacer(minLength: 0)
            Button("Not now", action: notNow)
                .buttonStyle(.ink)
                .help("Snooze 15 minutes. Free.")
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .flood(.turn)
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tenaz: three words in 20 seconds")
    }
}
