import SwiftUI
import TenazCore

/// First-launch onboarding (PLAN M9 scope, intrusions left off): Tena hatches, what Tenaz can do (all
/// OFF), the daily minimum, an if-then plan, then the placement test. Finishing saves the plan and the
/// stage evidence that hatches Tena (`OnboardingRecord.finish`); closing early leaves it for the next launch.
struct OnboardingRoot: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var navigator
    @Environment(TodayModel.self) private var today
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = OnboardingPage.welcome
    @State private var hatched = false
    @State private var plan = OnboardingPlan()
    @State private var problem: String?

    var body: some View {
        OnboardingFlow(page: page, hatched: hatched, plan: $plan, problem: problem,
                       actions: OnboardingActions(next: next, back: back, close: close, hatch: hatch))
    }

    private func hatch() {
        withAnimation(Motion.animation(.pop, reduceMotion: reduceMotion)) { hatched = true }
    }

    private func next() {
        guard let following = OnboardingPage(rawValue: page.rawValue + 1) else { return finish() }
        withAnimation(Motion.animation(.settle, reduceMotion: reduceMotion)) { page = following }
    }

    private func back() {
        guard let previous = OnboardingPage(rawValue: page.rawValue - 1) else { return }
        withAnimation(Motion.animation(.settle, reduceMotion: reduceMotion)) { page = previous }
    }

    private func close() {
        dismiss()
    }

    private func finish() {
        // A second press after a save problem goes on without the plan: never block the placement test.
        problem = OnboardingRecord.finish(plan: plan, env: env, navigator: navigator, skipPlan: problem != nil)
        guard problem == nil else { return }
        today.refresh()
        dismiss()
    }
}
