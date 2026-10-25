import Foundation
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest review-ui`: drives the screen's `ReviewModel` (not just the session API) on the
    /// in-memory database: answers every card it is shown (every third one wrong, waiting out learning
    /// steps by moving the clock), and checks review_log rows, XP from the engine, and the end screen.
    static func reviewUI(environment env: AppEnvironment) -> Int32 {
        let model = ReviewModel(env: env)
        var finished = -1
        model.onFinish = { finished = $0 }
        var now = Date()
        model.start(now: now)
        var shown = 0
        var phases: [String] = []
        loop: while shown < 40 {
            switch model.state.phase {
            case let .question(card):
                let wrong = shown % 3 == 2
                if card.isChoice {
                    model.choose(wrong ? ((card.correctOption ?? 0) + 1) % 4 : card.correctOption ?? 0)
                } else if card.type == .production {
                    model.typed = wrong ? "no" : "I want to \(card.headword) today at work."
                    model.submit()
                } else {
                    model.typed = wrong ? "zzz" : card.expected ?? ""
                    model.submit()
                }
                shown += 1
                if case let .feedback(_, feedback) = model.state.phase {
                    phases.append("\(card.id) \(feedback.correct ? "right" : "wrong") +\(feedback.xp)xp \(feedback.correct ? "" : feedback.backInText)")
                }
                now += 1
                model.next(now: now)
            case .checkpoint:
                phases.append("checkpoint at \(model.state.progress.correctToday) correct today")
                model.next(now: now)
            case let .waiting(until):
                phases.append("waiting \(Int(until.timeIntervalSince(now)))s")
                now = until.addingTimeInterval(1)
                model.advance(now: now)
            case .done, .empty, .loading:
                break loop
            case .feedback:
                now += 1
                model.next(now: now)
            }
        }
        if case .done = model.state.phase {} else { model.stop() }
        for line in phases {
            print(line)
        }
        let logs = (try? env.database?.reader.read { try ReviewLogRecord.fetchCount($0) }) ?? 0
        let xp = model.state.progress.xp
        guard case let .done(summary) = model.state.phase else {
            print("review-ui FAIL: not done")
            return 1
        }
        print("answered \(summary.answered) correct \(summary.correct) xp \(summary.xp) bestCombo \(summary.bestCombo) "
            + "correctToday \(summary.correctToday) qualified \(summary.dayQualified) review_log \(logs) finished(\(finished)) mood \(summary.mood.rawValue)")
        let ok = logs == summary.answered && summary.answered > 0 && xp > 0 && finished == summary.answered
        print(ok ? "review-ui OK" : "review-ui FAIL")
        return ok ? 0 : 1
    }
}
