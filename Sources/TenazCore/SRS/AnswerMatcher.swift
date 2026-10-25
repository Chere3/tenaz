import Foundation

/// Compares typed answers with the target (PLAN F3): normalization, accepted variants, and a
/// one-letter slip on a long word counted as a near miss.
public enum AnswerMatcher {
    /// Shortest word where a one-letter slip still counts (as Hard).
    public static let nearMissMinLetters = 6

    public static func match(_ typed: String, expected: String, accepted: [String] = []) -> MatchResult {
        let t = normalize(typed)
        guard !t.isEmpty else { return .wrong }
        if t == normalize(expected) { return .exact }
        if accepted.contains(where: { normalize($0) == t }) { return .accepted }
        if ([expected] + accepted).contains(where: { isNearMiss(t, normalize($0)) }) { return .nearMiss }
        return .wrong
    }

    /// Lowercase, straight apostrophes, no punctuation, single spaces (shared with exam scoring).
    public static func normalize(_ s: String) -> String { ObjectiveScorer.normalize(s) }

    /// Same words except exactly one, which is one edit away from a target word of 6+ letters.
    static func isNearMiss(_ typed: String, _ target: String) -> Bool {
        let a = typed.split(separator: " ").map(String.init)
        let b = target.split(separator: " ").map(String.init)
        guard a.count == b.count else { return false }
        let diffs = zip(a, b).filter { $0 != $1 }
        guard diffs.count == 1, let (x, y) = diffs.first else { return false }
        return y.count >= nearMissMinLetters && levenshtein(x, y) == 1
    }

    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }
}
