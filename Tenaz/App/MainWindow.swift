import AppKit
import SwiftUI

/// The main window: the Riso sidebar + one screen. Owned by the home builder for layout; other builders
/// only replace their own root views (one case each below). While this window is open Tenaz is a regular
/// app with a Dock icon; when it closes, Tenaz goes back to living in the menu bar only.
struct MainWindow: View {
    @Environment(Navigator.self) private var navigator
    @Environment(TodayModel.self) private var today
    @State private var sidebarVisible = true

    var body: some View {
        @Bindable var nav = navigator
        HStack(spacing: 0) {
            if sidebarVisible {
                SidebarView(selection: $nav.route, summary: today.summary)
                    .transition(.move(edge: .leading))
            }
            Group {
                switch navigator.route {
                case .home: HomeView()
                case .review: ReviewRoot()
                case .placement: PlacementEntryView()
                case .exams: ExamsRoot()
                case .library: LibraryRoot()
                case .achievements: AchievementsRoot()
                case .quests: QuestsRoot()
                case .weeklyReview: WeeklyReviewRoot()
                case .contract: ContractRoot()
                case .settings: SettingsRoot()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .paperBackground()
        .frame(minWidth: 900, minHeight: 620)
        .background {
            Button("Toggle Sidebar", action: toggleSidebar)
                .keyboardShortcut("s", modifiers: [.command, .control])
                .hidden()
        }
        .sheet(isPresented: $nav.showOnboarding, onDismiss: today.refresh) { OnboardingRoot() }
        .sheet(isPresented: $nav.showWrite, onDismiss: today.refresh) { WriteSheet() }
        .onAppear(perform: appeared)
        .onDisappear(perform: disappeared)
        .onChange(of: navigator.route) { today.refresh() }
        .onChange(of: today.summary) { _, summary in
            if !LaunchArguments.current.isAutomation { DockIcon.update(summary) }
        }
    }

    private func toggleSidebar() {
        withAnimation(.snappy) { sidebarVisible.toggle() }
    }

    private func appeared() {
        guard !LaunchArguments.current.isAutomation else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        today.refresh()
        DockIcon.update(today.summary, force: true)
        Self.prepareLaunch(navigator, onboardingCompleted: OnboardingRecord.isCompleted())
    }

    /// A window opening: it shows the route it was opened on (Today on a fresh launch), with
    /// onboarding on top until it is finished. If the popover asked for the Write sheet, that sheet
    /// wins this time (two sheets on one view would fight) and onboarding waits for the next open.
    static func prepareLaunch(_ navigator: Navigator, onboardingCompleted: Bool) {
        if !onboardingCompleted, !navigator.showWrite { navigator.showOnboarding = true }
    }

    private func disappeared() {
        guard !LaunchArguments.current.isAutomation else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
