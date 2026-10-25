import AppKit
import SwiftUI
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest exam-window`: the "Take it in this window" fallback answered end to end with
    /// keyboard events, in a normal window hosting the same ExamRunnerView the Exams screen shows.
    /// Return starts sections, 2 picks an option, typing fills a gap and the email. In-memory database.
    static func examWindow(environment env: AppEnvironment) async -> Int32 {
        setvbuf(stdout, nil, _IONBF, 0)
        Task.detached {
            try? await Task.sleep(for: .seconds(20))
            print("exam-window FAIL: 20 s watchdog fired")
            exit(3)
        }
        guard let blueprint = try? JSONDecoder().decode(ExamBlueprint.self, from: Data(examLiveBlueprint.utf8)) else { return 1 }
        var ok = true
        func check(_ name: String, _ pass: Bool, _ detail: String) {
            print("\(pass ? "ok  " : "FAIL") \(name): \(detail)")
            ok = ok && pass
        }
        let center = ExamCenter.shared
        center.start(blueprint, examMode: false)
        guard case let .running(runner) = center.screen else {
            print("exam-window FAIL: not running in the window (\(center.problem ?? "no problem"))")
            return 1
        }
        check("noPanel", !center.mode.isShowing && !runner.examMode, "Exam Mode showing \(center.mode.isShowing), examMode \(runner.examMode)")

        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 1180, height: 800),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ExamRunnerView(runner: runner, onLeave: {}).environment(env))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        await pause(0.8)

        press("\r", 36, window)
        await pause(0.5)
        check("returnStartsSection", runner.phase == .task && runner.kind == .grammar, "phase \(runner.phase)")
        press("2", 19, window)
        await pause(0.3)
        check("digitPicks", runner.draft.choices.first == 1, "choice \(String(describing: runner.draft.choices.first))")
        press("\r", 36, window)
        await pause(0.5)
        press("\r", 36, window)
        await pause(0.8)
        check("gapsShown", runner.kind == .completeWords, "kind \(runner.kind.map { "\($0)" } ?? "none"), first responder \(responderName(window))")
        typeText("ab", window)
        await pause(0.4)
        check("typingFillsGap", runner.draft.gaps.first == "ab", "gaps \(runner.draft.gaps.prefix(3))")
        for _ in 0..<(runner.draft.gaps.count + 1) where runner.kind == .completeWords {
            press("\r", 36, window)
            await pause(0.15)
        }
        await pause(0.3)
        press("\r", 36, window)
        await pause(0.8)
        check("writingFocused", runner.kind == .writing, "kind \(runner.kind.map { "\($0)" } ?? "none"), first responder \(responderName(window))")
        typeText("hello world", window)
        await pause(0.4)
        check("typingReachesModel", runner.draft.text == "hello world", "draft text \"\(runner.draft.text)\"")

        runner.abort(reason: "self-test")
        window.close()
        print(ok ? "exam-window OK" : "exam-window FAIL")
        return ok ? 0 : 1
    }
}
