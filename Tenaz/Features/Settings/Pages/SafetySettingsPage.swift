import SwiftUI
import TenazCore

/// Every escape hatch and how to use it (PLAN §5.2), the live state of the kill switches, and how
/// often each hatch was used this week (counted, never blocked).
struct SafetySettingsPage: View {
    @Bindable var model: SettingsModel
    @Environment(IntrusionCoordinator.self) private var intrusions

    private var weekCounts: [HatchKind: Int] {
        let today = DayBoundary.day(for: Date())
        return (try? intrusions.store?.hatchCounts(days: LearningDays.adding(-6, to: today)...today)) ?? [:]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            SettingsPageHeader(title: "Safety", subtitle: "Tenaz can never lock you out. Every way out is here, and every one always works.")
            IntrusionStatusBanner(anythingOn: model.anythingOn, killSwitch: intrusions.killState)
            SettingsCard(title: "Ways out", systemImage: "lifepreserver") {
                ForEach(EscapeHatch.all) { hatch in
                    EscapeHatchRow(hatch: hatch)
                }
            }
            SettingsCard(title: "Right now", systemImage: "switch.2") {
                SettingsRow(title: "Hotkey kill switch", detail: intrusions.killState.hotkeyUntil.map { $0 > Date() ? "On until \($0.formatted(date: .omitted, time: .shortened))" : "Off" } ?? "Off") {
                    Chip(intrusions.killState.hotkeyUntil.map { $0 > Date() } ?? false ? "On" : "Off", state: .idle)
                }
                SettingsRow(title: "Terminal kill switch", detail: "defaults key killSwitch") {
                    Chip(intrusions.killState.defaultsKey ? "On" : "Off", state: .idle)
                }
                SettingsRow(title: "Kill switch file", detail: "DISABLE_OVERLAYS") {
                    Chip(intrusions.killState.fileFlag ? "Present" : "Absent", state: .idle)
                }
                if intrusions.killState.hotkeyUntil.map({ $0 > Date() }) ?? false || intrusions.killState.defaultsKey {
                    Button("Turn the kill switch off", systemImage: "arrow.uturn.backward", action: intrusions.killSwitch.reset)
                        .buttonStyle(.ink)
                }
            }
            SettingsCard(title: "Used this week", systemImage: "chart.bar.fill", note: "Counted for your Sunday review. Using a way out is never punished by the app itself.") {
                HatchCountsRow(counts: weekCounts)
            }
        }
    }
}
