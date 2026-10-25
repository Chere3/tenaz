import SwiftUI
import TenazCore

/// The progress area's snapshot screens, built from `ProgressDemo` only when rendered (so other
/// areas' snapshots never pay for the demo database).
struct ProgressSnapshot: View {
    enum Screen {
        case achievements, quests, weeklyReview, library, knowledgeCard
    }

    let screen: Screen
    let vocab: [VocabEntry]

    var body: some View {
        if let demo = ProgressDemo.shared {
            content(demo)
        } else {
            Text("Demo data failed to build").paperBackground()
        }
    }

    @ViewBuilder private func content(_ demo: ProgressDemo.Fixture) -> some View {
        switch screen {
        case .achievements:
            AchievementsScreen(achievements: (try? demo.engine.state().achievements) ?? [])
        case .quests:
            if let state = try? demo.engine.state() {
                QuestsScreen(model: QuestsModel(state: state, now: demo.now, calendar: ProgressDemo.calendar))
            }
        case .weeklyReview:
            if let report = try? demo.weekly.report(now: demo.now, stages: demo.engine.stages) {
                WeeklyReviewScreen(report: report, openContract: {})
            }
        case .library:
            if let model = try? LibraryModel.build(content: LibraryBundle.content, store: demo.library, now: demo.now, calendar: ProgressDemo.calendar) {
                LibraryScreen(model: model)
            }
        case .knowledgeCard:
            if let card = LibraryBundle.content.knowledge.first(where: { $0.id == "kn-how-llms-write" }) {
                KnowledgeReader(card: card, gloss: GlossIndex(vocab: vocab), goDeeper: LibraryBundle.content.item(card.goDeeper),
                                initialAnswer: "With more context, the model can predict what our team needs.")
            }
        }
    }
}
