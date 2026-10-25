import SwiftUI

/// The section list: quiet rows, the chosen one on a card fill. ↑/↓ move between sections.
struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .padding(.bottom, Tokens.Space.s)
                .padding(.leading, Tokens.Space.s)
            ForEach(SettingsSection.allCases) { section in
                let on = section == selection
                Button { selection = section } label: {
                    Label(section.title, systemImage: section.symbol)
                        .font(.system(size: 14, weight: on ? .bold : .medium, design: .rounded))
                        .foregroundStyle(on ? Tokens.ink : Tokens.brand)
                        .padding(.horizontal, Tokens.Space.s)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        .background { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Tokens.card : .clear) }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                if section == .credits { Spacer(minLength: Tokens.Space.s).frame(maxHeight: Tokens.Space.m) }
            }
            Spacer()
        }
        .padding(Tokens.Space.m)
        .frame(width: 214)
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(.upArrow) { move(-1) }
    }

    private func move(_ by: Int) -> KeyPress.Result {
        let all = SettingsSection.allCases
        guard let i = all.firstIndex(of: selection) else { return .ignored }
        selection = all[(i + by + all.count) % all.count]
        return .handled
    }
}
