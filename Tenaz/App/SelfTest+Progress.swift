import Foundation
import TenazCore

extension SelfTest {
    /// Builds the progress demo (real engine and stores, throwaway in-memory database) and checks
    /// every screen's data: 53 achievements, 3 quests, a full weekly review, a recommendation set,
    /// a Brain bite whose targets resolve, and clean library content. Touches no real data.
    static func progress(environment env: AppEnvironment) -> Int32 {
        guard let demo = ProgressDemo.shared else { print("progress demo failed"); return 1 }
        do {
            let state = try demo.engine.state()
            let report = try demo.weekly.report(now: demo.now, stages: demo.engine.stages)
            let content = LibraryBundle.content
            let library = try LibraryModel.build(content: content, store: demo.library, now: demo.now, calendar: ProgressDemo.calendar)
            let problems = content.problems(vocab: env.content.vocab)
            let cold = Recommender.pick(content.catalog, profile: .coldStart)
            let unlocked = state.achievements.filter(\.isUnlocked).map(\.id)
            print("achievements \(state.achievements.count) unlocked \(unlocked)")
            print("quests \(state.quests.map { "\($0.slot.rawValue) \($0.progress)/\($0.target)\($0.done ? " done" : "")" }) weekly \(state.weeklyQuest?.title ?? "none")")
            print("weekly days7 \(report.daysPracticed7) days30 \(report.daysPracticed30) mastered \(report.masteredNow) (+\(report.masteredGained7)) "
                + "errors \(report.errors.map(\.category)) rules \(report.rules.map { "\($0.rule) \(Int($0.stats.escapeRate * 100))%\($0.suggestTurnOff ? " off?" : "")" }) "
                + "killSwitch \(report.hatches.killSwitch) renegotiate \(report.hatches.asksRenegotiation) automaticityDue \(report.automaticityDue)")
            print("library catalog \(content.catalog.count) knowledge \(content.knowledge.count) problems \(problems.count) "
                + "coldStart \(cold.map { $0.all.map(\.id) } ?? []) demo inProgress \(library.inProgress.map(\.id)) next \(library.reading?.all.map(\.id) ?? []) "
                + "listen \(library.listening.map(\.id)) brainBite \(library.brainBite?.id ?? "none") minutes7 \(library.minutesThisWeek)")
            let ok = state.achievements.count == 53 && state.quests.count == 3 && report.last7.count == 7
                && report.masteredSeries.count == 30 && problems.isEmpty && cold != nil && library.brainBite != nil
            return ok ? 0 : 1
        } catch {
            print("progress selftest failed: \(error)")
            return 1
        }
    }
}
