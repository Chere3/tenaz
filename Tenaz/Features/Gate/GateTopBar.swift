import SwiftUI

/// The emergency skip (always visible, priced honestly, a text button) and the time left on the page.
struct GateTopBar: View {
    @Bindable var model: GateModel

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let wait = model.skipWait(at: context.date)
                Button { model.openSkip() } label: {
                    HStack(spacing: 6) {
                        KeyCap("Esc ×2")
                        Text(wait > 0 ? "Emergency skip in \(wait) s" : "Emergency skip · \(model.price.short)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Tokens.ink)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(wait > 0)
                .help("Press Esc twice. You see the cost before anything happens.")
            }
            if model.phase == .skipArmed {
                Text("Press Esc again to skip")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.ink)
                    .transition(.opacity)
            }
            Spacer(minLength: Tokens.Space.l)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, model.deadline.timeIntervalSince(context.date))
                HStack(spacing: Tokens.Space.s) {
                    Text("Max 5 min")
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                    InkBand(remaining: left / GateModel.maxOnScreen,
                            readout: String(format: "%d:%02d", Int(left) / 60, Int(left) % 60))
                        .frame(width: 220)
                }
            }
        }
    }
}
