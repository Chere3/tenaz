import SwiftUI

/// A one-line text field in the progress screens. Off-screen snapshots cannot draw AppKit fields,
/// so they get a SwiftUI stand-in with the same frame.
struct ProgressField: View {
    let prompt: String
    @Binding var text: String
    var onSubmit: () -> Void = {}
    /// Tells the screen when typing starts and stops, so its digit shortcuts step aside.
    var onFocusChange: (Bool) -> Void = { _ in }
    @Environment(\.isSnapshot) private var isSnapshot
    @FocusState private var focused: Bool

    var body: some View {
        if isSnapshot {
            Text(text.isEmpty ? prompt : text)
                .font(Typography.body)
                .foregroundStyle(text.isEmpty ? Tokens.brand.opacity(0.55) : Tokens.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Space.s)
                .padding(.vertical, 10)
                .background { RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous).fill(Tokens.card) }
        } else {
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .focused($focused)
                .onSubmit(onSubmit)
                .onChange(of: focused) { _, now in onFocusChange(now) }
                .padding(.horizontal, Tokens.Space.s)
                .padding(.vertical, 10)
                .background { RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous).fill(Tokens.card) }
                .overlay {
                    if focused {
                        RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
                            .strokeBorder(Tokens.ink, lineWidth: 2)
                    }
                }
        }
    }
}

/// A round check (SwiftUI-drawn, so snapshots show it): ink at 12 % off, brand with a tick on.
struct ProgressCheck: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: Tokens.Space.xs) {
                ZStack {
                    Circle().fill(isOn ? Tokens.ink : Tokens.ink.opacity(0.12))
                    if isOn {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Tokens.inverse)
                    }
                }
                .frame(width: 20, height: 20)
                Text(title).font(Typography.labelBold).foregroundStyle(Tokens.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}
