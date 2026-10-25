import AppKit
import SwiftUI
import TenazCore

/// Where Tenaz keeps your data (only on this Mac).
struct DataSettingsPage: View {
    @Environment(AppEnvironment.self) private var env
    @State private var loginOn = LoginItem.isRegistered
    @State private var loginStatus = LoginItem.statusText

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            SettingsPageHeader(title: "Data", subtitle: "Everything stays on this Mac. Nothing is uploaded, except the text Claude grades.")
            SettingsCard(title: "Your files", systemImage: "externaldrive") {
                SettingsRow(title: "Folder", detail: env.paths.root.path) {
                    Button("Show in Finder", systemImage: "folder", action: reveal).buttonStyle(.ink)
                }
                SettingsRow(title: "Database", detail: "tenaz.sqlite: reviews, exams, Tena, your writing.") {
                    Chip(env.database == nil ? "Not open" : "OK", systemImage: "cylinder", state: env.database == nil ? .idle : .done)
                }
                SettingsRow(title: "Bundled content", detail: "\(env.content.vocab.count) words and chunks, \(env.content.items.count) exam items.") {
                    Chip("Loaded", systemImage: "books.vertical", state: .done)
                }
            }
            #if !TENAZ_DEV_BUILD
            // Only the installed Tenaz opens at login (a TenazDev login item too would mean two gates).
            SettingsCard(title: "Startup", systemImage: "power") {
                SettingsRow(title: "Open at login", detail: "Tenaz opens when you log in. Now: \(loginStatus).") {
                    Toggle("Open at login", isOn: $loginOn)
                        .labelsHidden().toggleStyle(.riso)
                        .onChange(of: loginOn) { _, on in setLogin(on) }
                }
            }
            .onAppear {
                loginOn = LoginItem.isRegistered
                loginStatus = LoginItem.statusText
            }
            #endif
        }
    }

    private func setLogin(_ on: Bool) {
        try? LoginItem.set(on)
        loginStatus = LoginItem.statusText
        loginOn = LoginItem.isRegistered
    }

    private func reveal() {
        try? FileManager.default.createDirectory(at: env.paths.root, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([env.paths.root])
    }
}
