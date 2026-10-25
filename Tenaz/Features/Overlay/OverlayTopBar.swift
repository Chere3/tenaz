import SwiftUI

/// Top of the card: the skip hatch (left, always visible), progress segments, time left.
struct OverlayTopBar: View {
    let index: Int
    let total: Int
    let skipCost: Int
    let deadline: Date
    var compact = false
    let skip: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Button(action: skip) {
                HStack(spacing: 6) {
                    KeyCap("Esc")
                    Text(compact ? "Skip" : (skipCost == 0 ? "Skip · free" : "Skip · −\(skipCost) Vitality"))
                        .font(.system(size: compact ? 12 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.ink)
                }
            }
            .buttonStyle(.plain)
            .help(skipCost == 0 ? "Skip this batch. It costs nothing: Response cost is off in your contract." : "Skip this batch. Your contract charges \(skipCost) Vitality.")
            Spacer(minLength: Tokens.Space.xs)
            OverlayPips(index: index, total: total, compact: compact)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, deadline.timeIntervalSince(context.date))
                let readout = String(format: "%d:%02d", Int(left) / 60, Int(left) % 60)
                if compact {
                    Text(readout)
                        .font(Typography.numeric(13))
                        .foregroundStyle(Tokens.ink)
                        .accessibilityLabel("Time left \(readout)")
                } else {
                    InkBand(remaining: left / 90, readout: readout).frame(width: 150)
                }
            }
        }
    }
}
