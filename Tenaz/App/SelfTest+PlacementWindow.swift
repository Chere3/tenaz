import Foundation

extension SelfTest {
    /// The "Exam Mode not working? Take it in this window" safety net: the real placement starts in the
    /// main window (no full-screen panel) and can be answered there. In-memory database; voids at the end.
    static func placementWindow() -> Int32 {
        let center = ExamCenter.shared
        center.startPlacementInWindow()
        guard case let .running(runner) = center.screen else {
            print("placement-window FAIL: not running in the window (\(center.problem ?? "no problem"))")
            return 1
        }
        let ok = !runner.examMode && !center.mode.isShowing && runner.blueprint.kind == .placement
        print("placement-window: examMode \(runner.examMode), panel up \(center.mode.isShowing), sections \(runner.blueprint.sections.count)")
        runner.abort(reason: "self-test")
        print(ok ? "placement-window OK" : "placement-window FAIL")
        return ok ? 0 : 1
    }
}
