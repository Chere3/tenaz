import SwiftUI

/// Sound preferences. Sound always mutes itself in meetings.
struct SoundSettingsPage: View {
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            SettingsPageHeader(title: "Sound", subtitle: "Short, soft sounds for right and wrong answers. Always muted during meetings.")
            SettingsCard(title: "Sound", systemImage: "speaker.wave.2.fill") {
                SettingsRow(title: "Play sounds") {
                    Toggle("Play sounds", isOn: $model.soundEnabled).labelsHidden().toggleStyle(.riso)
                }
                SettingsRow(title: "Volume") {
                    RisoStepper(value: $model.soundVolume, range: 0...100, step: 10) { "\($0) %" }
                        .disabled(!model.soundEnabled)
                }
                SettingsRow(title: "Calm celebrations", detail: "No shake, no confetti, no flashes. Good for tired days.") {
                    Toggle("Calm celebrations", isOn: $model.calmCelebrations).labelsHidden().toggleStyle(.riso)
                }
            }
        }
    }
}
