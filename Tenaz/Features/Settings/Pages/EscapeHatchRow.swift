import SwiftUI

/// One hatch: glyph, name, keys, one plain sentence, and a copyable command when there is one.
struct EscapeHatchRow: View {
    let hatch: EscapeHatch

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s) {
            Image(systemName: hatch.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.brand)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Tokens.Space.xs) {
                    Text(hatch.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Tokens.ink)
                    Spacer(minLength: Tokens.Space.xs)
                    HStack(spacing: 3) {
                        ForEach(hatch.keys, id: \.self) { KeyCap($0) }
                    }
                }
                Text(hatch.what)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
                if let command = hatch.command { CommandLineStrip(command: command) }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
