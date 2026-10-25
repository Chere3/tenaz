import SwiftUI

/// The page for one section.
struct SettingsPage: View {
    let section: SettingsSection
    @Bindable var model: SettingsModel

    var body: some View {
        switch section {
        case .intrusions: IntrusionsSettingsPage(model: model)
        case .gate: GateSettingsPage(model: model)
        case .exams: ExamsSettingsPage()
        case .claude: ClaudeSettingsPage(model: model)
        case .sound: SoundSettingsPage(model: model)
        case .data: DataSettingsPage()
        case .credits: CreditsSettingsPage()
        case .safety: SafetySettingsPage(model: model)
        }
    }
}
