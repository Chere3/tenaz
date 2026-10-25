import AppKit
import SwiftUI

/// Today, live: reads the shared `TodayModel` and routes the buttons.
struct HomeView: View {
    @Environment(TodayModel.self) private var today
    @Environment(Navigator.self) private var navigator

    var body: some View {
        HomeBoard(summary: today.summary, actions: HomeActions(
            primary: primary, dailyCheck: dailyCheck, write: write, quests: quests, level: level, hatch: hatch
        ))
        .onAppear(perform: today.refresh)
    }

    private func primary() {
        switch today.summary.primary {
        case .placement: navigator.route = .placement
        case .review, .comeBack: navigator.route = .review
        case .allDone: break
        }
    }

    private func hatch() {
        navigator.showOnboarding = true
    }

    private func dailyCheck() {
        navigator.route = .exams
    }

    private func write() {
        navigator.showWrite = true
    }

    private func quests() {
        navigator.route = .quests
    }

    private func level() {
        navigator.route = today.summary.placementTaken ? .exams : .placement
    }
}
