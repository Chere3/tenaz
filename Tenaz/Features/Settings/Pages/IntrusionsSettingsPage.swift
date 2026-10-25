import SwiftUI
import TenazCore

/// Overlay on/off, mode, caps, quiet hours and triggers. All OFF by default; enabling needs
/// Calendar access or the "detection only" acknowledgement first (F14).
struct IntrusionsSettingsPage: View {
    @Bindable var model: SettingsModel
    @Environment(IntrusionCoordinator.self) private var intrusions

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            SettingsPageHeader(title: "Intrusions", subtitle: "Three words that come to you between tasks. They wait until you stop typing, and never show during a meeting.")
            MeetingSafetyCard(model: model)
            SettingsCard(title: "Word overlays", systemImage: "textformat.size.larger") {
                SettingsRow(title: "Show word overlays", detail: model.lockReason ?? "Up to 3 words, about 30 seconds. Esc always skips.") {
                    Toggle("Show word overlays", isOn: $model.settings.overlaysEnabled).labelsHidden().toggleStyle(.riso)
                        .disabled(!model.canEnable && !model.settings.overlaysEnabled)
                }
                Group {
                SettingsRow(title: "Size", detail: "Poster covers most of the screen. Sticker is a small card in the corner, with no sound.") {
                    RisoSegmented(options: [(OverlayMode.sticker, "Sticker"), (OverlayMode.poster, "Poster")], selection: $model.settings.overlayMode)
                }
                SettingsRow(title: "Batches a day", detail: "Never more than 8.") {
                    RisoStepper(value: $model.settings.overlaysPerDay, range: 1...IntrusionSettings.maxOverlaysPerDay) { "\($0) a day" }
                }
                SettingsRow(title: "Time between batches", detail: "At least 40 minutes.") {
                    RisoStepper(value: $model.settings.overlayGapMinutes, range: IntrusionSettings.minOverlayGapMinutes...240, step: 10) { "\($0) min" }
                }
                }
                .opacity(model.settings.overlaysEnabled ? 1 : 0.4)
                .disabled(!model.settings.overlaysEnabled)
            }
            SettingsCard(title: "When they may come", systemImage: "arrow.triangle.branch",
                         note: "Only at natural breaks, never in the middle of a task.") {
                SettingsRow(title: "After you unlock or wake the Mac") {
                    Toggle("Unlock", isOn: $model.settings.triggers.unlock).labelsHidden().toggleStyle(.riso)
                }
                SettingsRow(title: "When you come back after 5+ minutes away") {
                    Toggle("Idle return", isOn: $model.settings.triggers.idleReturn).labelsHidden().toggleStyle(.riso)
                }
                SettingsRow(title: "When you switch apps after 25+ minutes in one app", detail: "It waits for deep focus to end.") {
                    Toggle("App switch", isOn: $model.settings.triggers.appSwitch).labelsHidden().toggleStyle(.riso)
                }
            }
            .opacity(model.settings.overlaysEnabled ? 1 : 0.4)
            .disabled(!model.settings.overlaysEnabled)
            QuietHoursCard(quiet: $model.settings.quietHours)
            Text("Last decision: \(intrusions.lastDecision)")
                .font(Typography.caption)
                .foregroundStyle(Tokens.brand)
        }
    }
}
