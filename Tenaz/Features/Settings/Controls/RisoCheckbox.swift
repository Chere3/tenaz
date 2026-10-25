import SwiftUI

/// A flat checkbox with a sentence: used for the F14 "I understand" acknowledgement.
struct RisoCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: Tokens.Space.s) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? Tokens.ink : Tokens.ink.opacity(0.15))
                    .overlay {
                        if isOn { Image(systemName: "checkmark").font(.system(size: 12, weight: .black)).foregroundStyle(Tokens.inverse) }
                    }
                    .frame(width: 22, height: 22)
                Text(title)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "Checked" : "Unchecked")
    }
}
