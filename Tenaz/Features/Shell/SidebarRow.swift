import SwiftUI

/// One destination: glyph + title. Selected = ink text, bolder, on an 8 % ink capsule (shape and
/// weight, never colour alone); the rest are quiet brand text.
struct SidebarRow: View {
    let route: Route
    let selected: Bool
    var badge: Int?
    var shortcut: KeyEquivalent?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: route.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20)
                Text(route.title)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(Typography.numeric(12))
                        .foregroundStyle(Tokens.ink)
                }
            }
            .foregroundStyle(selected ? Tokens.ink : Tokens.brand)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background {
                Capsule().fill(Tokens.ink.opacity(selected ? 0.08 : hovering ? 0.05 : 0))
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .modifier(OptionalShortcut(key: shortcut))
        .accessibilityLabel(route.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(badge.map { $0 > 0 ? "\($0) words" : "" } ?? "")
    }
}
