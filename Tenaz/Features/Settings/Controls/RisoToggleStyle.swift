import SwiftUI

/// A flat switch: ink track when on, ink at 15 % when off, a paper knob with a glyph (check / dash), so
/// the state never relies on colour. Disabled = faint track and a lock. Pure SwiftUI (snapshots).
/// Only the switch is drawn: the settings row prints the title next to it.
struct RisoToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        RisoToggleBody(configuration: configuration)
    }
}

extension ToggleStyle where Self == RisoToggleStyle {
    static var riso: RisoToggleStyle { RisoToggleStyle() }
}

private struct RisoToggleBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 0) {
                // Rows print their own title; the label stays for VoiceOver only.
                configuration.label
                    .frame(width: 0)
                    .opacity(0)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn && isEnabled ? Tokens.ink : Tokens.ink.opacity(isEnabled ? 0.15 : 0.08))
                        .frame(width: 50, height: 28)
                    Circle()
                        .fill(Tokens.paper)
                        .overlay {
                            Image(systemName: !isEnabled ? "lock.fill" : (configuration.isOn ? "checkmark" : "minus"))
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Tokens.ink.opacity(isEnabled ? 1 : 0.5))
                        }
                        .frame(width: 22, height: 22)
                        .padding(.horizontal, 3)
                }
                .animation(Motion.animation(.tap, reduceMotion: reduceMotion), value: configuration.isOn)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
