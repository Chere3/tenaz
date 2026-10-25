import AppKit
import SwiftUI
import TenazCore

@main
struct TenazApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var env = AppDelegate.environment
    @State private var navigator = AppDelegate.navigator
    @State private var today = AppDelegate.today

    var body: some Scene {
        MenuBarExtra {
            LiveMenuPopover()
                .environment(env)
                .environment(navigator)
                .environment(today)
        } label: {
            Image(nsImage: TenaGlyph.image(today.summary.glyphState))
        }
        .menuBarExtraStyle(.window)

        Window("Tenaz", id: "main") {
            MainWindow()
                .environment(env)
                .environment(navigator)
                .environment(today)
                .environment(AppDelegate.intrusions)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 800)
        .defaultLaunchBehavior(LaunchArguments.current.isAutomation ? .suppressed : .presented)

        Settings {
            SettingsRoot()
                .environment(env)
                .environment(navigator)
                .environment(today)
                .environment(AppDelegate.intrusions)
        }
        #if TENAZ_DEV_BUILD
        Window("Gallery", id: "gallery") {
            GalleryWindow()
        }
        .defaultLaunchBehavior(.suppressed)
        #endif
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let environment = AppEnvironment(inMemory: LaunchArguments.current.isAutomation)
    static let navigator = Navigator()
    static let today = TodayModel(env: environment)
    /// Every intrusive surface and its kill switches (all OFF by default).
    static let intrusions = IntrusionCoordinator(env: environment)

    func applicationWillFinishLaunching(_ notification: Notification) {
        Typography.registerFonts()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement starts Tenaz as a menu-bar app; MainWindow switches to a regular app (Dock icon)
        // while it is open and back when it closes.
        let args = LaunchArguments.current
        if let action = args.loginItem {
            exit(LoginItem.runCommand(action))
        }
        if let name = args.snapshot {
            exit(Snapshot.render(name, to: args.output ?? ".derived/shots/\(name).png", environment: Self.environment))
        }
        if let surface = args.smoke {
            Smoke.run(surface, environment: Self.environment)
            return
        }
        if let name = args.selftest {
            Task { exit(await SelfTest.run(name, environment: Self.environment)) }
            return
        }
        Self.intrusions.start()
        Self.environment.grading.start()
        ExamCenter.shared.creditLeftovers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.environment.grading.stop()
    }
}
