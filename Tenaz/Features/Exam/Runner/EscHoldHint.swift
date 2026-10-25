import SwiftUI

/// "Hold Esc 3 s to leave": a keycap with a ring that fills while Esc is held.
struct EscHoldHint: View {
    let progress: Double

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            if progress > 0 {
                ZStack {
                    Circle().stroke(Tokens.ink.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Tokens.wrong, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 18, height: 18)
            }
            Text("Hold")
            KeyCap("Esc")
            Text(progress > 0 ? "keep holding to leave" : "3 s to leave")
        }
        .font(Typography.label)
        .foregroundStyle(Tokens.ink.opacity(0.72))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hold Escape for 3 seconds to leave the test")
    }
}
