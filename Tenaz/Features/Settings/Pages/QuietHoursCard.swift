import SwiftUI
import TenazCore

/// Nightly quiet hours (default 22:30-08:00), in 30-minute steps.
struct QuietHoursCard: View {
    @Binding var quiet: QuietHours

    var body: some View {
        SettingsCard(title: "Quiet hours", systemImage: "moon.stars.fill", note: "Tena sleeps. Nothing appears, ever.") {
            SettingsRow(title: "From") {
                RisoStepper(value: $quiet.startMinute, range: 0...(24 * 60 - 30), step: 30) { QuietHours.label($0) }
            }
            SettingsRow(title: "Until") {
                RisoStepper(value: $quiet.endMinute, range: 0...(24 * 60 - 30), step: 30) { QuietHours.label($0) }
            }
        }
    }
}
