import AppKit
import SwiftUI

/// Shows one SwiftUI view in overlay panels and guarantees they go away: any kill switch, the
/// watchdog (maximum time on screen) or app quit closes them.
@MainActor
final class OverlayPresenter {
    private var panels: [OverlayPanel] = []
    private var watchdog: Task<Void, Never>?
    private(set) var isShowing = false
    private(set) var layout: OverlayLayout?
    var onForcedClose: ((String) -> Void)?

    /// The interactive panel, if any (key window checks, "click to type").
    var mainPanel: OverlayPanel? { panels.first }

    func show<Content: View>(_ layout: OverlayLayout, maxOnScreen: Duration, activate: Bool = false, @ViewBuilder content: () -> Content) {
        close()
        self.layout = layout
        let primary = OverlayLayout.activeScreen()
        let screens = layout == .fullScreen ? [primary] + NSScreen.screens.filter { $0 != primary } : [primary]
        let root = AnyView(content())
        for (i, screen) in screens.enumerated() {
            let panel = OverlayPanel(frame: layout.frame(on: screen), interactive: layout.isInteractive && i == 0)
            // Other screens get a dim backdrop with the notification band cut out too: banners may
            // show on the menu-bar screen even when the pointer (and the page) is on another one.
            let view: AnyView = i == 0 ? root : AnyView(Color.black.opacity(0.82).ignoresSafeArea().clipShape(NotchedPage()))
            panel.contentView = FirstMouseHostingView(rootView: view)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        if layout.isInteractive, let main = panels.first {
            if activate { NSApp.activate() }
            main.makeKeyAndOrderFront(nil)
        }
        isShowing = true
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: maxOnScreen)
            guard !Task.isCancelled, let self else { return }
            self.close()
            self.onForcedClose?("timeout")
        }
    }

    /// The wave-1 signature, kept so other surfaces (exam panel) still compile: full screen or a
    /// poster-sized card; `acceptsTyping` activates the app so text fields work.
    func show<Content: View>(fullScreen: Bool, acceptsTyping: Bool, maxOnScreen: Duration, @ViewBuilder content: () -> Content) {
        show(fullScreen ? .fullScreen : .poster, maxOnScreen: maxOnScreen, activate: acceptsTyping, content: content)
    }

    func close() {
        watchdog?.cancel()
        watchdog = nil
        for p in panels {
            p.orderOut(nil)
            p.close()
        }
        panels.removeAll()
        isShowing = false
        layout = nil
    }
}
