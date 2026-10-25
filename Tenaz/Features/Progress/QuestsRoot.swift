import SwiftUI
import TenazCore

/// Loads today's quests from the gamification engine. Refreshes whenever it appears, so a quest
/// finished in a review shows as done when the learner comes back.
struct QuestsRoot: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var navigator
    @State private var model = QuestsModel.empty

    var body: some View {
        QuestsScreen(model: model,
                     startReviews: { navigator.route = .review },
                     openAchievements: { navigator.route = .achievements })
            .task { load() }
    }

    private func load() {
        guard let engine = env.gamification else { return }
        do { model = QuestsModel(state: try engine.state(), now: .now) } catch { NSLog("Tenaz: quests failed: \(error)") }
    }
}
