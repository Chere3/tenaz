import SwiftUI

/// The shortcut next to an action ("Return", "Esc"): a hairline keycap in the surrounding text colour,
/// at 60 % so it reads as a hint, not a second button. `fill` is ignored (kept for older call sites).
struct KeyCap: View {
    let key: String

    init(_ key: String, fill: Color = .clear) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(Typography.caption)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.foreground, lineWidth: 1.25)
            }
            .opacity(0.6)
            .accessibilityLabel("Shortcut \(key)")
    }
}
