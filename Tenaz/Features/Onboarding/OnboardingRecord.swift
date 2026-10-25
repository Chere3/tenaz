import Foundation
import TenazCore

/// What onboarding leaves behind. The "done" flag is in UserDefaults (the learner can see onboarding again
/// with `defaults delete com.chere3.tenaz.dev onboardingCompleted`); the if-then plan goes to the
/// `if_then_plan` table, the same one the weekly review lists and adds to.
enum OnboardingRecord {
    static let completedKey = "onboardingCompleted"

    static func isCompleted(_ defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: completedKey) }

    /// Finishes onboarding: saves the plan, merges the stage evidence, sets the flag and sends the
    /// window to the placement intro. Returns a problem to show when something could not be saved;
    /// then nothing is marked done, unless `skipPlan` (the learner pressed again to go on without it).
    static func finish(plan: OnboardingPlan, env: AppEnvironment, navigator: Navigator, defaults: UserDefaults = .standard,
                       now: Date = .now, skipPlan: Bool = false) -> String? {
        if !skipPlan, let cue = plan.planCue, let database = env.database {
            do {
                try WeeklyReviewStore(database: database).addPlan(cue: cue, action: OnboardingPlan.action, now: now)
            } catch {
                return "Your plan couldn't be saved (\(error.localizedDescription)). Press the button again to go on without it."
            }
        }
        do {
            try recordEvidence(env)
        } catch {
            NSLog("Tenaz: stage evidence not saved: \(error)")
            if !skipPlan { return "Tena's progress couldn't be saved (\(error.localizedDescription)). Press the button again to go on." }
        }
        defaults.set(true, forKey: completedKey)
        navigator.route = .placement
        return nil
    }

    /// Onboarding + level paragraph done, with the B1+ starting prior as the private band
    /// (stage 3 becomes reachable on the first qualified day). Merged, so a placement that already
    /// ran (its band, `placementDone`) and a Daily Check estimate are kept, never overwritten.
    static func recordEvidence(_ env: AppEnvironment) throws {
        guard let engine = env.gamification else { return }
        let band = env.database.flatMap { try? ExamStore(database: $0).publicBand() }
        try engine.mergeStageEvidence { e in
            e.onboardingDone = true
            e.levelParagraphDone = true
            e.privateBand = e.privateBand ?? band ?? StageEvidence.englishLevelPriorBand
            if let band {
                e.placementDone = true
                e.placementBand = e.placementBand ?? band
                e.publicBand = e.publicBand ?? band
            }
        }
    }
}
