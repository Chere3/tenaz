import SwiftUI

/// The session bar: thin segments along the top, "esc stop" under them, and (only after an answer)
/// the session's XP as one quiet line on the right (the combo is in the answer's hero).
struct ReviewHeader: View {
    let progress: ReviewProgress
    let stop: () -> Void
    var stopsWithEscape = true
    /// Pause screens carry their own "Stop here" (Esc), so the bar shows only the segments.
    var showsStop = true
    /// XP appears only once a card has been answered.
    var showsScore = false

    private var score: String { "\(progress.xp) xp this session" }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            SessionSegments(answered: progress.answered, total: progress.total)
            HStack(spacing: Tokens.Space.m) {
                if showsStop {
                    Button(action: stop) {
                        HStack(spacing: 6) {
                            KeyCap("esc")
                            Text("stop")
                        }
                        .font(Typography.label)
                        .fixedSize()
                    }
                    .buttonStyle(.ink)
                    .padding(.leading, -Tokens.Space.s)
                    .accessibilityLabel("Stop")
                    .modifier(CancelShortcut(enabled: stopsWithEscape))
                }
                Spacer(minLength: 0)
                if showsScore {
                    Text(score)
                        .font(Typography.numeric(14))
                        .foregroundStyle(Tokens.brand)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }
            }
            .frame(minHeight: 32)
        }
        .accessibilityElement(children: .contain)
    }
}
