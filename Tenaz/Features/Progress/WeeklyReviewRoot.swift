import SwiftUI
import TenazCore

/// Builds this week's review from local data and saves the learner's answers.
struct WeeklyReviewRoot: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var navigator
    @State private var report: WeeklyReviewReport?
    @State private var problem: String?

    var body: some View {
        Group {
            if let report {
                WeeklyReviewScreen(report: report, problem: problem, openContract: { navigator.route = .contract }) { answers, automaticity, plan in
                    save(report, answers, automaticity, plan)
                }
            } else {
                ContentUnavailableView("Weekly review", systemImage: "calendar",
                                       description: Text(problem ?? "Your data could not be opened."))
                    .paperBackground()
            }
        }
        .task { load() }
    }

    private var store: WeeklyReviewStore? { env.database.map { WeeklyReviewStore(database: $0) } }

    private func load() {
        guard let store, let stages = env.gamification?.stages else { return }
        do { report = try store.report(now: .now, stages: stages) } catch {
            NSLog("Tenaz: weekly review failed: \(error)")
            problem = "This week's review couldn't be built: \(error.localizedDescription)"
        }
    }

    /// True when saved (the plan included). On failure the screen keeps what they typed and shows why.
    private func save(_ report: WeeklyReviewReport, _ answers: WeeklyReviewAnswers, _ automaticity: Int?,
                      _ plan: (cue: String, action: String)?) -> Bool {
        guard let store else {
            problem = "Your review couldn't be saved: the database isn't open."
            return false
        }
        do {
            try store.save(report: report, answers: answers, automaticity: automaticity, plan: plan, now: .now)
            problem = nil
            load()
            return true
        } catch {
            NSLog("Tenaz: saving the weekly review failed: \(error)")
            problem = "Your review couldn't be saved (\(error.localizedDescription)). Nothing was lost here; try again."
            return false
        }
    }
}
