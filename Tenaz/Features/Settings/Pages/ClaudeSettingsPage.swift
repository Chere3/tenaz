import SwiftUI
import TenazCore

/// Claude through the `claude` command and your claude.ai session (never an API key).
struct ClaudeSettingsPage: View {
    @Bindable var model: SettingsModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            SettingsPageHeader(title: "Claude", subtitle: "Claude grades your writing and speaking after you finish. Everything else works without it.")
            SettingsCard(title: "Grading", systemImage: "sparkle") {
                SettingsRow(title: "Use Claude", detail: "Through the claude command and your claude.ai plan. No API key.") {
                    Toggle("Use Claude", isOn: $model.claudeEnabled).labelsHidden().toggleStyle(.riso)
                }
                SettingsRow(title: "Model", detail: "Sonnet is fast and good. Opus is slower and stronger.") {
                    RisoSegmented(options: [("haiku", "Haiku"), ("sonnet", "Sonnet"), ("opus", "Opus")], selection: $model.claudeModel)
                }
                SettingsRow(title: "Command", detail: env.claude.executable.path) {
                    Chip(env.claude.isAvailable ? "Found" : "Missing", systemImage: env.claude.isAvailable ? "terminal" : "questionmark",
                         state: env.claude.isAvailable ? .done : .idle)
                }
                HStack(spacing: Tokens.Space.s) {
                    Button("Test connection", systemImage: "bolt.horizontal.circle", action: test)
                        .buttonStyle(.ink)
                        .disabled(model.claudeTest == .running || !model.claudeEnabled)
                    ClaudeTestResult(state: model.claudeTest)
                }
            }
        }
    }

    private func test() {
        Task { await model.testClaude(env.claude) }
    }
}
