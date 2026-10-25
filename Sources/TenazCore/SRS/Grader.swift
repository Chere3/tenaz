import Foundation

/// Answer → FSRS rating per card type (PLAN F3). There is no self-rating and no Easy.
public enum Grader {
    /// Recognition answered faster than this is Good; slower (but right) is Hard.
    public static let recognitionGoodMs = 6000

    /// R: wrong = Again; right in < 6 s = Good; right but slower = Hard (PLAN gives 6-12 s = Hard and
    /// is silent above 12 s; a slow right answer is still Hard).
    public static func recognition(correct: Bool, durationMs: Int) -> Rating {
        guard correct else { return .again }
        return durationMs < recognitionGoodMs ? .good : .hard
    }

    /// C, L, K, typed S: exact or accepted = Good, near miss = Hard, else Again.
    public static func typed(_ match: MatchResult) -> Rating {
        switch match {
        case .exact, .accepted: .good
        case .nearMiss: .hard
        case .wrong: .again
        }
    }

    /// nil when the answer kind does not fit the card (e.g. a typed answer for a P card).
    public static func rating(for prompt: CardPrompt, answer: ReviewAnswer, durationMs: Int) -> Rating? {
        switch (prompt.type, answer) {
        case let (.recognition, .choice(i)):
            recognition(correct: i == prompt.correctOption, durationMs: durationMs)
        case let (.cloze, .typed(s)), let (.recall, .typed(s)), let (.collocation, .typed(s)), let (.spelling, .typed(s)):
            typed(AnswerMatcher.match(s, expected: prompt.expected ?? "", accepted: prompt.accepted))
        case let (.production, .graded(r)), let (.spelling, .graded(r)):
            r
        default:
            nil
        }
    }
}
