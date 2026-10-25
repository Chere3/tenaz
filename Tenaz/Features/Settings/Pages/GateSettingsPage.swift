import SwiftUI
import TenazCore

/// The unlock gate: on/off, size, strict mode (set only in the Contract).
struct GateSettingsPage: View {
    @Bindable var model: SettingsModel
    @Environment(AppEnvironment.self) private var env

    private var strictOn: Bool {
        (try? env.gamification?.contract().isActive(.strictGate, at: Int64(Date().timeIntervalSince1970 * 1000))) ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            SettingsPageHeader(title: "Unlock gate", subtitle: "After you unlock the Mac, write 2–3 sentences in English before you start. It is not a lock: Esc twice, “Joining a call” and the kill switch always work.")
            SettingsCard(title: "Gate", systemImage: "lock.open.display") {
                SettingsRow(title: "Show the gate", detail: model.lockReason ?? "Max 3 a day, 2 hours apart, only after 30+ minutes locked (or the first unlock of the day). Max 5 minutes on screen.") {
                    Toggle("Show the gate", isOn: $model.settings.gateEnabled).labelsHidden().toggleStyle(.riso)
                        .disabled(!model.canEnable && !model.settings.gateEnabled)
                }
                SettingsRow(title: "Minimum words", detail: "The meter fills to 40. Unlock opens from this number.") {
                    RisoStepper(value: $model.settings.gateMinWords, range: 25...40, step: 5) { "\($0) words" }
                }
                SettingsRow(title: "Strict gate", detail: "The skip appears after 10 seconds. You can change this only in your Contract.") {
                    Chip(strictOn ? "On" : "Off", systemImage: strictOn ? "timer" : "minus", state: strictOn ? .active : .idle)
                }
            }
            SettingsCard(title: "After you write", systemImage: "sparkle") {
                Text("The gate checks your text on this Mac at once (length, English, the target word, variety). Claude grades it a few seconds after the gate closes, so you never wait.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
