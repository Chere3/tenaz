import SwiftUI

/// Pill, 14 pt label, glyph + word. idle = card, active = ink fill, done = green + check, locked = card fill with a lock glyph.
struct Chip: View {
    let title: String
    var systemImage: String?
    var state: ChipState = .idle

    init(_ title: String, systemImage: String? = nil, state: ChipState = .idle) {
        self.title = title
        self.systemImage = systemImage
        self.state = state
    }

    private var glyph: String? {
        switch state {
        case .done: "checkmark"
        case .locked: "lock.fill"
        default: systemImage
        }
    }

    private var fill: Color {
        switch state {
        case .idle: Tokens.card
        case .active: Tokens.ink
        case .done: Tokens.correct
        case .locked: Tokens.card
        }
    }

    private var foreground: Color {
        switch state {
        case .idle: Tokens.ink
        case .active, .done: Tokens.inverse
        case .locked: Tokens.brand
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            if let glyph {
                Image(systemName: glyph).font(.system(size: 11, weight: .bold))
            }
            Text(title).font(Typography.labelBold)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .frame(minHeight: 28)
        .background { Capsule().fill(fill) }
        .accessibilityElement(children: .combine)
        .accessibilityValue(state.rawValue)
    }
}
