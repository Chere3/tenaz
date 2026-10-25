import Foundation
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest home-state`: Today's primary-action decision for the three branches, then the
    /// live decision on this (fresh, in-memory) database. A fresh install must offer the placement test.
    static func homeState(environment env: AppEnvironment) -> Int32 {
        let branches: [(String, HomePrimary)] = [
            ("no placement", .decide(placementTaken: false, placementInProgress: false, placementMinutes: 48, todaySetCount: 9)),
            ("placement running", .decide(placementTaken: false, placementInProgress: true, placementMinutes: 48, todaySetCount: 9)),
            ("placement done, 9 in set", .decide(placementTaken: true, placementInProgress: false, placementMinutes: 48, todaySetCount: 9)),
            ("placement done, set empty", .decide(placementTaken: true, placementInProgress: false, placementMinutes: 48, todaySetCount: 0)),
        ]
        for (name, decision) in branches {
            print("branch \(name): \(decision.debugName) -> \"\(decision.title)\"")
        }
        let live = TodayLoader.load(env)
        print("live: placementTaken \(live.placementTaken) todaySet \(live.todaySetCount) stage \(live.stage.rawValue) \(live.stageName) "
            + "mood \(live.mood.rawValue) streak \(live.streakDays) level \(live.level)")
        print("live decision: \(live.primary.debugName) -> \"\(live.primary.title)\"")
        print("tena says: \(live.line)")
        if let write = live.write { print("write prompt: \(write.id) \(write.prompt)") }
        let ok: Bool = if case .placement = live.primary {
            live.todaySetCount > 0
        } else {
            false
        }
        // Day 1 after a session: answer the set right once (each card then waits 10 min), Stop, look again.
        let model = ReviewModel(env: env)
        model.start()
        var answered = 0
        while case let .question(card) = model.state.phase, answered < 10 {
            if card.isChoice { model.choose(card.correctOption ?? 0) } else { model.typed = card.expected ?? ""; model.submit() }
            answered += 1
            model.next(now: .now.addingTimeInterval(1))
        }
        model.stop()
        let after = TodayLoader.load(env)
        let placed = HomePrimary.decide(placementTaken: true, placementInProgress: false, placementMinutes: 48,
                                        todaySetCount: after.todaySetCount, comingBack: after.comingBack)
        print("after \(answered) answers and Stop: todaySet \(after.todaySetCount) comingBack \(after.comingBack?.count ?? 0) "
            + "-> with placement taken: \(placed.debugName) \"\(placed.title)\"")
        let comesBack: Bool = if case .comeBack = placed { true } else { false }
        let pass = ok && comesBack
        print(pass ? "home-state OK" : "home-state FAIL")
        return pass ? 0 : 1
    }
}
