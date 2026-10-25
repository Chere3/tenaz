import SwiftUI

/// "?" shows the hint (progressive disclosure, R2): the Spanish gloss or the definition, one line.
struct OverlayHint: View {
    let hint: String?
    let shown: Bool
    var compact = false
    let toggle: () -> Void

    var body: some View {
        if let hint, !hint.isEmpty {
            if shown {
                Text(hint)
                    .font(.system(size: compact ? 13 : 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Button(action: toggle) {
                    HStack(spacing: 6) {
                        Text("Hint")
                        KeyCap("?")
                    }
                }
                .buttonStyle(.ink)
            }
        }
    }
}
