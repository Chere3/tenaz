import AppKit
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest exam-live`: the real Exam Mode path with keyboard and mouse events injected
    /// in-process (no Accessibility needed). Tenaz becomes a regular, active app with a key window
    /// standing in for the main one (as MainWindow does), starts a three-section exam through
    /// `ExamCenter.start` (what the Start button runs), then checks that the panel is key, that
    /// Return, 1-4, Tab, typing and a click reach the answers, that holding Esc 3 s shows the leave
    /// card, and that leaving voids the attempt and closes the panel. In-memory database; a detached
    /// 20 s watchdog exits even if the main thread hangs.
    static func examLive(environment env: AppEnvironment) async -> Int32 {
        setvbuf(stdout, nil, _IONBF, 0)
        Task.detached {
            try? await Task.sleep(for: .seconds(20))
            print("exam-live FAIL: 20 s watchdog fired")
            exit(3)
        }
        guard let blueprint = try? JSONDecoder().decode(ExamBlueprint.self, from: Data(examLiveBlueprint.utf8)) else {
            print("exam-live: bad blueprint")
            return 1
        }
        var ok = true
        func check(_ name: String, _ pass: Bool, _ detail: String) {
            print("\(pass ? "ok  " : "FAIL") \(name): \(detail)")
            ok = ok && pass
        }

        // The main window as the learner has it when they click Start: Tenaz regular, active, a key window.
        let main = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 900, height: 620),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        main.title = "Tenaz"
        main.isReleasedWhenClosed = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        main.makeKeyAndOrderFront(nil)
        await pause(0.6)
        // Key status needs an active app. A locked screen (overnight) or a terminal that keeps
        // activation leaves Tenaz inactive: the key checks are then skipped and say why, while the
        // events still run through NSApp.sendEvent, the Esc monitor and the panel's responder chain.
        let locked = (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
        let canKey = NSApp.isActive
        print("activation: policy \(NSApp.activationPolicy() == .regular ? "regular" : "other"), isActive \(NSApp.isActive), "
            + "main window key \(main.isKeyWindow), screen locked \(locked)")
        func keyCheck(_ name: String, _ pass: Bool, _ detail: String) {
            // Activation can land after the start-up probe: decide at check time, not once at launch.
            if canKey || NSApp.isActive { check(name, pass, detail) } else { print("skip \(name) (Tenaz is not active\(locked ? ", screen locked" : "")): \(detail)") }
        }

        let center = ExamCenter.shared
        center.start(blueprint)
        let mode = center.mode
        guard let runner = mode.runner, let panel = mode.panel else {
            print("exam-live FAIL: Exam Mode did not open (\(center.problem ?? "no problem reported"))")
            return 1
        }
        await pause(1.0)
        await pause(1.2)
        check("keyboardGuard", mode.keyboardLost == !panel.isKeyWindow,
              "panel key \(panel.isKeyWindow), banner \(mode.keyboardLost ? "shown" : "hidden")")
        keyCheck("panelKey", panel.isKeyWindow && NSApp.keyWindow === panel,
              "canBecomeKey \(panel.canBecomeKey), isKeyWindow \(panel.isKeyWindow), NSApp.keyWindow is panel \(NSApp.keyWindow === panel), "
                + "isActive \(NSApp.isActive), first responder \(responderName(panel))")

        // Section 1 intro: Return starts it.
        press("\r", 36, panel)
        await pause(0.6)
        check("returnStartsSection", runner.phase == .task && runner.kind == .grammar,
              "phase \(runner.phase), kind \(runner.kind.map { "\($0)" } ?? "none"), first responder \(responderName(panel))")

        // Grammar item: "2" picks the second option, Return hands it in.
        press("2", 19, panel)
        await pause(0.3)
        check("digitPicks", runner.draft.choices.first == 1, "choice \(runner.draft.choices.first.flatMap { $0 }.map(String.init) ?? "none")")
        press("\r", 36, panel)
        await pause(0.4)
        check("returnAdvances", runner.phase == .intro && runner.section?.id == "r",
              "phase \(runner.phase), section \(runner.section?.id ?? "none")")

        // Complete the Words: the first gap has focus, typing fills it, Tab moves on, a click focuses a gap.
        press("\r", 36, panel)
        await pause(0.8)
        let gaps = textViews(in: panel.contentView)
        let firstGap = panel.firstResponder as? ExamTextView
        check("gapFocused", runner.kind == .completeWords && firstGap != nil && firstGap === gaps.first,
              "kind \(runner.kind.map { "\($0)" } ?? "none"), \(gaps.count) gap fields, first responder \(responderName(panel))")
        typeText("ab", panel)
        await pause(0.3)
        check("typingFillsGap", runner.draft.gaps.first == "ab", "gaps \(runner.draft.gaps.prefix(3))")
        press("\t", 48, panel)
        await pause(0.4)
        let secondGap = panel.firstResponder as? ExamTextView
        typeText("c", panel)
        await pause(0.3)
        check("tabMovesGap", secondGap != nil && secondGap !== firstGap && runner.draft.gaps[safe: 1] == "c",
              "first responder \(responderName(panel)), gaps \(runner.draft.gaps.prefix(3))")

        // The panel loses key (another window took it), then a click into the first gap.
        main.makeKey()
        await pause(0.3)
        let keyBeforeClick = panel.isKeyWindow
        // Click near the end of the gap, where you click to keep typing (gaps are sized to their letters).
        if let target = gaps.first { click(target, in: panel, atEnd: true) }
        await pause(0.4)
        typeText("d", panel)
        await pause(0.3)
        check("clickFocusesField", panel.firstResponder === gaps.first && runner.draft.gaps.first == "abd",
              "first responder is gap 1 \(panel.firstResponder === gaps.first), gaps \(runner.draft.gaps.prefix(3))")
        // Either the click keys the panel or the keyboard guard already took it back: both are fine.
        keyCheck("clickKeysPanel", panel.isKeyWindow, "key before click \(keyBeforeClick) (guard), after \(panel.isKeyWindow)")

        // Tenaz coming back to the front (Cmd-Tab, Dock) with the main window key: the panel takes the keyboard back.
        main.makeKey()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared,
                                                   userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current])
        await pause(0.3)
        keyCheck("reactivationKeysPanel", panel.isKeyWindow && NSApp.keyWindow === panel, "panel key \(panel.isKeyWindow), main key \(main.isKeyWindow)")

        // Return walks the gaps and hands the paragraph in on the last one.
        for _ in 0..<(runner.draft.gaps.count + 1) where runner.kind == .completeWords {
            press("\r", 36, panel)
            await pause(0.15)
        }
        await pause(0.3)
        check("returnHandsInGaps", runner.phase == .intro && runner.section?.id == "w", "phase \(runner.phase), section \(runner.section?.id ?? "none")")

        // Writing: the page has focus and typing reaches the stored answer.
        press("\r", 36, panel)
        await pause(0.8)
        let page = panel.firstResponder as? ExamTextView
        check("writingFocused", runner.kind == .writing && page?.multiline == true,
              "kind \(runner.kind.map { "\($0)" } ?? "none"), first responder \(responderName(panel))")
        typeText("hello world", panel)
        await pause(0.4)
        check("typingReachesModel", runner.draft.text == "hello world", "draft text \"\(runner.draft.text)\"")

        // Hold Esc 3 s (with key repeats, as a real hold sends): the leave card appears.
        press("\u{1B}", 53, panel, phase: .keyDown)
        for _ in 0..<33 {
            await pause(0.1)
            press("\u{1B}", 53, panel, phase: .keyDown, isRepeat: true)
        }
        await pause(0.2)
        let confirming = mode.confirmingLeave
        press("\u{1B}", 53, panel, phase: .keyUp)
        await pause(0.2)
        check("escHoldShowsLeave", confirming, "confirmingLeave \(confirming)")

        // Return on the card is "Keep going" and must not reach the page behind it.
        press("\r", 36, panel)
        await pause(0.4)
        check("returnKeepsGoing", !mode.confirmingLeave && runner.phase == .task && runner.draft.text == "hello world"
                && page != nil && panel.firstResponder === page,
              "confirmingLeave \(mode.confirmingLeave), phase \(runner.phase), draft text \"\(runner.draft.text)\", "
                + "page has the keyboard again \(page != nil && panel.firstResponder === page)")

        // Leave through the card's button action: voided, the panel gone, the main window back.
        press("\u{1B}", 53, panel, phase: .keyDown)
        await pause(3.3)
        let confirmedAgain = mode.confirmingLeave
        press("\u{1B}", 53, panel, phase: .keyUp)
        mode.leave()
        await pause(0.6)
        let panelsUp = NSApp.windows.compactMap { $0 as? OverlayPanel }.filter(\.isVisible).count
        check("leaveVoids", confirmedAgain && runner.phase == .voided && !mode.isShowing && panelsUp == 0,
              "confirm shown \(confirmedAgain), phase \(runner.phase), Exam Mode showing \(mode.isShowing), overlay panels visible \(panelsUp), "
                + "main window key \(main.isKeyWindow)")

        main.close()
        print(ok ? "exam-live OK" : "exam-live FAIL")
        return ok ? 0 : 1
    }

    /// Three one-task sections in a fixed order: one 1-4 item, one gap paragraph, one email.
    static let examLiveBlueprint = """
    {"id": "exam-live-v1", "kind": "weekly", "title": "Live Check",
     "sections": [
       {"id": "g", "title": "Grammar", "skill": "grammar", "minutes": 2, "picks": [{"types": ["grammarMC"], "count": 1}]},
       {"id": "r", "title": "Reading", "skill": "reading", "minutes": 2, "picks": [{"types": ["completeWords"], "count": 1}]},
       {"id": "w", "title": "Write an Email", "skill": "writing", "minutes": 2, "picks": [{"types": ["writeEmail"], "count": 1}]}]}
    """

    static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    static func responderName(_ window: NSWindow) -> String {
        window.firstResponder.map { String(describing: Swift.type(of: $0)) } ?? "none"
    }

    /// Every exam text field in the panel, in view order (for gaps: paragraph order).
    static func textViews(in view: NSView?) -> [ExamTextView] {
        guard let view else { return [] }
        if let field = view as? ExamTextView { return [field] }
        return view.subviews.flatMap { textViews(in: $0) }
    }

    /// One key event through `NSApp.sendEvent`, the way the window server's events arrive (so the
    /// local Esc monitor and the key window's responder chain both see it). Down and up unless a phase is given.
    static func press(_ characters: String, _ keyCode: UInt16, _ window: NSWindow, modifiers: NSEvent.ModifierFlags = [],
                              phase: NSEvent.EventType? = nil, isRepeat: Bool = false) {
        for type in phase.map({ [$0] }) ?? [.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: modifiers,
                                               timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                               context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                               isARepeat: isRepeat, keyCode: keyCode) else { continue }
            NSApp.sendEvent(event)
        }
    }

    static func typeText(_ text: String, _ window: NSWindow) {
        for ch in text {
            let s = String(ch)
            press(s, keyCodes[s] ?? 0, window)
        }
    }

    /// A left click in the middle of `view`.
    private static func click(_ view: NSView, in window: NSWindow, atEnd: Bool = false) {
        let x = atEnd ? view.bounds.maxX - 2 : view.bounds.midX
        let point = view.convert(NSPoint(x: x, y: view.bounds.midY), to: nil)
        func event(_ type: NSEvent.EventType) -> NSEvent? {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                               pressure: type == .leftMouseDown ? 1 : 0)
        }
        guard let down = event(.leftMouseDown), let up = event(.leftMouseUp) else { return }
        // The text view tracks the drag in its own loop until the mouse-up: queue it first.
        NSApp.postEvent(up, atStart: false)
        NSApp.sendEvent(down)
    }

    /// ANSI key codes for the letters the test types.
    static let keyCodes: [String: UInt16] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "h": 4, "l": 37, "o": 31, "r": 15, "w": 13, " ": 49,
    ]
}
