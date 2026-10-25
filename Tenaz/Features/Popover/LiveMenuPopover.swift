import AppKit
import SwiftUI

/// The menu-bar popover wired to live state: today's summary, and actions that open the main window
/// on the right screen. The pause hatch is instant and free (it only marks the day, PLAN F9/F10).
struct LiveMenuPopover: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var navigator
    @Environment(TodayModel.self) private var today
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var pausedUntil = IntrusionPause.until()

    var body: some View {
        MenuPopover(state: PopoverState(today.summary, pausedUntil: pausedUntil), actions: PopoverActions(
            review: primary, write: write, exam: exam, quests: quests,
            pauseIntrusions: togglePause, quietHours: settings, openApp: { show(nil) }
        ))
        .onAppear(perform: appeared)
    }

    private func appeared() {
        today.refresh()
        pausedUntil = IntrusionPause.until()
    }

    private func primary() {
        switch today.summary.primary {
        case .placement: show(.placement)
        case .review, .comeBack: show(.review)
        case .allDone: show(.home)
        }
    }

    private func write() {
        show(.home)
        // Onboarding already on screen keeps the window's one sheet; Write waits until it is closed.
        if !navigator.showOnboarding { navigator.showWrite = true }
    }

    private func exam() {
        show(today.summary.placementTaken ? .exams : .placement)
    }

    private func quests() {
        show(.quests)
    }

    private func togglePause() {
        if pausedUntil != nil {
            IntrusionPause.resume()
            pausedUntil = nil
            return
        }
        // The coordinator sets the pause, logs the hatch, credits gamification and closes anything visible.
        AppDelegate.intrusions.pauseOneHour()
        pausedUntil = IntrusionPause.until()
    }

    private func settings() {
        NSApp.activate()
        openSettings()
    }

    /// Opens (or brings back) the main window, optionally on a screen.
    private func show(_ route: Route?) {
        if let route { navigator.route = route }
        openWindow(id: "main")
        NSApp.activate()
    }
}
