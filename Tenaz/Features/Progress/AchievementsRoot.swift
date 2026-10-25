import SwiftUI
import TenazCore

/// Loads the achievements from the gamification engine and shows them.
struct AchievementsRoot: View {
    @Environment(AppEnvironment.self) private var env
    @State private var achievements: [AchievementProgress] = []

    var body: some View {
        AchievementsScreen(achievements: achievements)
            .task { load() }
    }

    private func load() {
        guard let engine = env.gamification else { return }
        do { achievements = try engine.state().achievements } catch { NSLog("Tenaz: achievements failed: \(error)") }
    }
}
