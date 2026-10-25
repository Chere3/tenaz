import SwiftUI
import TenazCore

/// Settings (PLAN F13): also the Settings scene (⌘,). Every intrusive switch ships off; the Safety
/// page lists every way out.
struct SettingsRoot: View {
    @State private var selection: SettingsSection
    @State private var model = SettingsModel()
    @Environment(\.isSnapshot) private var isSnapshot

    init(initial: SettingsSection = .intrusions) {
        _selection = State(initialValue: initial)
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)
            Rectangle().fill(Tokens.ink.opacity(0.12)).frame(width: Tokens.rule)
            if isSnapshot {
                // ImageRenderer does not draw scroll views: lay the page out flat.
                page.frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView { page }
            }
        }
        .frame(minWidth: 640, minHeight: 520)
        .paperBackground()
        .onAppear { model.refresh() }
    }

    private var page: some View {
        SettingsPage(section: selection, model: model)
            .padding(Tokens.Space.l)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
