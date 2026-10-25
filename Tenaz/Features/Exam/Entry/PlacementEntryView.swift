import SwiftUI
import TenazCore

/// The Placement route: loads the plan and any unfinished attempt, then shows the intro.
struct PlacementEntryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openWindow) private var openWindow
    @State private var state = PlacementEntryState(sections: [], totalMinutes: 0)
    private let center = ExamCenter.shared

    var body: some View {
        PlacementIntroView(state: state, witness: center.witness, paused: center.paused != nil,
                           problem: center.problem, calendarBlocked: center.calendarBlocked, actions: actions)
            .task(id: center.revision) {
                state = .load(blueprint: env.blueprints.blueprint(for: .placement), store: center.store)
                center.openMainWindow = { openWindow(id: "main") }
                await center.refreshWitness()
            }
    }

    private var actions: PlacementIntroActions {
        PlacementIntroActions(
            start: center.startPlacement,
            startInWindow: center.startPlacementInWindow,
            resume: { if let id = state.unfinished?.id { center.resume(id) } },
            resumePaused: { center.resumePaused() },
            startAnyway: center.startAnyway,
            showLast: { if let last = state.last { center.showResults(last.id, kind: .placement) } })
    }
}

struct PlacementIntroActions {
    var start: () -> Void = {}
    var startInWindow: () -> Void = {}
    var resume: () -> Void = {}
    var resumePaused: () -> Void = {}
    var startAnyway: () -> Void = {}
    var showLast: () -> Void = {}
}
