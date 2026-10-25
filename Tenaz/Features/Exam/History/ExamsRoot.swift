import SwiftUI
import TenazCore

/// The Exams route: the overview (history, resume, Daily Check, mocks), a Daily Check running in
/// the window, or a result.
struct ExamsRoot: View {
    @Environment(\.openWindow) private var openWindow
    @State private var state = ExamsOverviewState()
    private let center = ExamCenter.shared

    var body: some View {
        Group {
            switch center.screen {
            case let .running(runner):
                ExamRunnerView(runner: runner, onLeave: { center.leaveRunning(runner) })
            case let .results(model):
                ExamResultsView(model: model, onNext: center.goReview, onHistory: center.closeResults)
            case .overview:
                ExamsOverview(state: state, paused: center.paused != nil, pausedForMeeting: center.pausedReason == .meeting,
                              pausedId: center.paused?.session.id, problem: center.problem,
                              calendarBlocked: center.calendarBlocked, actions: actions)
            }
        }
        .task(id: center.revision) {
            state = .load(store: center.store)
            center.openMainWindow = { openWindow(id: "main") }
        }
        .onChange(of: center.environment.grading.revision) {
            // A grade finished in the background (the app's one queue): refresh what is on screen.
            if case let .results(model) = center.screen { model.gradingProgressed() }
            state = .load(store: center.store)
        }
    }

    private var actions: ExamsOverviewActions {
        ExamsOverviewActions(
            daily: center.startDailyCheck,
            weekly: { center.startMock(.weekly) },
            monthly: { center.startMock(.monthly) },
            // The Placement route has the pledge, Continue for an unfinished attempt, and "Take it again".
            placement: center.openPlacement,
            resume: center.resume,
            resumePaused: { center.resumePaused() },
            resumeNotInCall: { center.resumePaused(notInACall: true) },
            startAnyway: center.startAnyway,
            open: { summary in center.showResults(summary.id, kind: summary.kind) })
    }
}
