import Foundation
import GRDB
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest first-run`: walks a fresh launch on the automation in-memory database with the
    /// code the windows run: Today → onboarding sheet → placement intro, Today's primary saying "Take
    /// your placement test" until a placement attempt is done, then switching to reviews. The onboarding
    /// flag goes to a throwaway defaults suite (removed at the end); no Claude call.
    static func firstRun(environment env: AppEnvironment) async -> Int32 {
        let suite = "com.chere3.tenaz.selftest.first-run"
        guard let defaults = UserDefaults(suiteName: suite), let database = env.database,
              let blueprint = env.blueprints.blueprint(for: .placement) else {
            print("first-run: no defaults suite, database or placement blueprint")
            return 1
        }
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        var ok = true
        func step(_ n: Int, _ text: String, _ pass: Bool) {
            print("step \(n) \(pass ? "ok  " : "FAIL") \(text)")
            ok = ok && pass
        }
        func count(_ table: String) -> Int {
            (try? database.reader.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM \(table)") }) ?? -1
        }
        do {
            let store = ExamStore(database: database)

            // 1. A fresh launch: nothing taken, onboarding not done, the window on Today.
            let navigator = Navigator()
            step(1, "fresh launch: exam_attempt \(count("exam_attempt")), onboarding done \(OnboardingRecord.isCompleted(defaults)), "
                + "window opens on \(navigator.route.title)",
                 count("exam_attempt") == 0 && !OnboardingRecord.isCompleted(defaults) && navigator.route == .home)

            // 2. The window appears (MainWindow.appeared): the onboarding sheet goes on top.
            MainWindow.prepareLaunch(navigator, onboardingCompleted: OnboardingRecord.isCompleted(defaults))
            step(2, "main window appeared: onboarding sheet \(navigator.showOnboarding ? "shown" : "not shown")", navigator.showOnboarding)

            // 3. Today behind the sheet offers the placement test.
            var today = TodayLoader.load(env)
            step(3, "Today primary: \(today.primary.debugName) \"\(today.primary.title)\"",
                 today.primary.title == "Take your placement test")

            // 4. Onboarding's last step (OnboardingRoot.finish): plan saved, evidence merged, placement intro.
            var plan = OnboardingPlan()
            plan.cue = OnboardingPlan.cues[1]
            let problem = OnboardingRecord.finish(plan: plan, env: env, navigator: navigator, defaults: defaults)
            navigator.showOnboarding = false
            let plans = try await database.reader.read { try IfThenPlanRecord.filter(Column("active") == true).fetchAll($0) }
            let evidence = try env.gamification?.stageEvidence()
            step(4, "onboarding finished: problem \(problem ?? "none"), route \(navigator.route.title), "
                + "if_then_plan \(plans.map(\.sentence)), onboardingDone \(evidence?.onboardingDone ?? false), "
                + "privateBand \(evidence?.privateBand.map { BandWords.format($0) } ?? "nil")",
                 problem == nil && navigator.route == .placement && plans.count == 1 && plans.first?.action == OnboardingPlan.action
                    && evidence?.onboardingDone == true && OnboardingRecord.isCompleted(defaults))

            // 5. The placement intro (PlacementEntryView) loads its plan with nothing to continue.
            let entry = PlacementEntryState.load(blueprint: blueprint, store: store)
            step(5, "placement intro: \(entry.sections.count) parts, \(entry.totalMinutes) min, "
                + "unfinished \(entry.unfinished?.where ?? "none"), last \(entry.last?.id ?? "none")",
                 !entry.sections.isEmpty && entry.unfinished == nil && entry.last == nil)

            // 6. Reopening the window now does not show onboarding again; Today still asks for the test.
            let reopened = Navigator()
            MainWindow.prepareLaunch(reopened, onboardingCompleted: OnboardingRecord.isCompleted(defaults))
            today = TodayLoader.load(env)
            step(6, "next launch: onboarding \(reopened.showOnboarding ? "shown" : "not shown"), Today \"\(today.primary.title)\"",
                 !reopened.showOnboarding && today.primary.title == "Take your placement test")

            // 7. The placement starts; until it is submitted Today offers to continue it.
            let clock = TestClock(Date())
            var session = ExamSession(blueprint: blueprint, library: env.content, priors: try store.priors(for: .placement),
                                      seed: 11, clock: clock)
            try store.begin(session)
            var learner = SimulatedLearner(theta: -0.3, seed: 5)
            for _ in 0..<3 {
                guard let task = session.currentTask else { break }
                clock.advance(by: 20)
                session.answer(learner.answer(task))
                try store.recordResponse(session, taskId: task.id)
            }
            today = TodayLoader.load(env)
            step(7, "placement under way: placementTaken \(today.placementTaken), Today \"\(today.primary.title)\"",
                 !today.placementTaken && today.primary.title == "Continue your placement test")

            // 8. Submitted (writing grades may still be pending): Today switches to the reviews.
            while let task = session.currentTask {
                clock.advance(by: 20)
                session.answer(learner.answer(task))
                try store.recordResponse(session, taskId: task.id)
            }
            guard let outcome = session.submit() else {
                print("first-run: the placement did not submit")
                return 1
            }
            try store.save(session, outcome: outcome)
            today = TodayLoader.load(env)
            let reviews: Bool = if case .review = today.primary { true } else { false }
            step(8, "placement submitted (pending grades \(outcome.pendingSkills.map(\.rawValue))): placementTaken \(today.placementTaken), "
                + "Today \(today.primary.debugName) \"\(today.primary.title)\", set \(today.todaySetCount), "
                + "popover Exam opens \(today.placementTaken ? Route.exams.title : Route.placement.title)",
                 today.placementTaken && reviews && today.todaySetCount > 0)
        } catch {
            print("first-run error: \(error)")
            return 1
        }
        print(ok ? "first-run OK" : "first-run FAIL")
        return ok ? 0 : 1
    }
}
