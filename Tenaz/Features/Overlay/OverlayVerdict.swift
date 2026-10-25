import SwiftUI

/// Feedback after Return (tier S reward / penalty, under 100 ms). Wrong never shames: it shows the
/// right answer big, their try struck through, and when the word comes back. Ink on the flood, always.
struct OverlayVerdict: View {
    let phase: OverlayPhase
    var compact = false
    /// The pill's action in the poster (the same advance Return performs).
    var next: (() -> Void)?

    var body: some View {
        switch phase {
        case let .correct(xp):
            HStack(spacing: Tokens.Space.s) {
                Label("Remembered", systemImage: "checkmark.circle.fill")
                    .font(compact ? Typography.display(18) : Typography.displayM)
                    .foregroundStyle(Tokens.ink)
                Text("+\(xp) XP")
                    .font(Typography.numeric(compact ? 14 : 22))
                    .foregroundStyle(Tokens.ink)
            }
        case let .wrong(expected, given):
            VStack(alignment: .leading, spacing: compact ? 2 : Tokens.Space.xs) {
                HStack(spacing: Tokens.Space.s) {
                    Text("You wrote")
                        .font(.system(size: compact ? 12 : 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.brand)
                    Text(given)
                        .font(.system(size: compact ? 12 : 22, weight: .medium, design: .rounded))
                        .strikethrough(true, color: Tokens.ink)
                        .foregroundStyle(Tokens.ink.opacity(0.6))
                        .lineLimit(1)
                }
                Text(expected)
                    .font(Typography.display(compact ? 36 : 180))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Label("Back in 1 min", systemImage: "arrow.uturn.backward")
                    .font(.system(size: compact ? 12 : 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                if !compact, let next {
                    Button(action: next) {
                        HStack(spacing: Tokens.Space.s) {
                            Text("Next")
                            KeyCap("Return")
                        }
                    }
                    .buttonStyle(.fat)
                    .frame(width: 180)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, Tokens.Space.s)
                }
            }
        default:
            EmptyView()
        }
    }
}
