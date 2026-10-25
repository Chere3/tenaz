import Foundation
import Observation
import TenazCore

/// The live `TodaySummary`, shared by Today, the sidebar header, the popover and the menu-bar glyph.
/// Refresh after anything that changes progress (a review answer, a finished session, onboarding)
/// and whenever a surface appears; reading is a few small queries.
@Observable
final class TodayModel {
    private(set) var summary: TodaySummary
    @ObservationIgnored private let env: AppEnvironment

    init(env: AppEnvironment) {
        self.env = env
        summary = TodayLoader.load(env)
    }

    func refresh() {
        let next = TodayLoader.load(env)
        if next != summary { summary = next }
    }

    /// Saves the scheduler counts the engine needs for mood, quests and achievements, then refreshes.
    func syncLearning() {
        if let store = env.reviewStore, let engine = env.gamification,
           let snapshot = try? store.learningSnapshot(now: .now, stages: engine.stages)
        {
            do { try engine.updateLearning(snapshot) } catch { NSLog("Tenaz: updateLearning failed: \(error)") }
        }
        refresh()
    }
}
