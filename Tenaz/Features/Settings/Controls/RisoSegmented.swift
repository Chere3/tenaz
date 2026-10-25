import SwiftUI

/// A row of flat pills; the chosen one is filled with ink and gets a check.
struct RisoSegmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                let on = value == selection
                Button { selection = value } label: {
                    HStack(spacing: 4) {
                        if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .black)) }
                        Text(title).font(Typography.labelBold)
                    }
                    .foregroundStyle(on ? Tokens.inverse : Tokens.ink)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 28)
                    .background { Capsule().fill(on ? Tokens.ink : Tokens.ink.opacity(0.08)) }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
