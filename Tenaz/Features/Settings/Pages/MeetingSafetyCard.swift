import SwiftUI
import TenazCore

/// F14: Tenaz must see meetings before anything can be switched on. Calendar access (asked only
/// from this button) or the explicit "detection only" acknowledgement.
struct MeetingSafetyCard: View {
    @Bindable var model: SettingsModel
    @Environment(IntrusionCoordinator.self) private var intrusions

    var body: some View {
        SettingsCard(title: "Meeting safety · needed first", systemImage: "person.2.wave.2.fill",
                     note: "Nothing appears while your mic or camera is on, a presentation is open, or your calendar shows an event. (Focus modes are not read yet.)") {
            SettingsRow(title: "Calendar", detail: model.calendarGranted ? "Tenaz can see your meetings." : "Not allowed yet. Meetings in your calendar are invisible to Tenaz.") {
                if model.calendarGranted {
                    Chip("Allowed", state: .done)
                } else {
                    Button("Allow Calendar…", systemImage: "calendar.badge.checkmark", action: askCalendar)
                        .buttonStyle(.ink)
                }
            }
            // Only needed while Calendar is not allowed; once it is, the state would contradict itself.
            if !model.calendarGranted {
                RisoCheckbox(title: "I understand: without Calendar, Tenaz only sees the mic, the camera and which app is in front. A muted meeting could be missed.",
                             isOn: $model.settings.detectionOnlyAck)
            }
        }
    }

    private func askCalendar() {
        Task { await model.requestCalendar(probes: intrusions.probes) }
    }
}
