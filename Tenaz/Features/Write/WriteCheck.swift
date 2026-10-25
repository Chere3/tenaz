import Foundation
import NaturalLanguage
import TenazCore

/// Local checks for today's writing (no Claude needed): words, sentences, target words used,
/// English or not, and a 0-1 quality for XP. Claude's rubric can grade the saved entry later.
struct WriteCheck: Equatable {
    /// At least one real sentence: this many words counts for the daily minimum.
    static let minimumWords = 6

    let words: Int
    let goal: Int
    /// Target words/structures that can be checked by text, and whether each appears.
    let targets: [(String, Bool)]
    let looksEnglish: Bool

    init(text: String, prompt: TodayWritePrompt?) {
        words = TextMetrics(text: text).wordCount
        goal = prompt?.minWords ?? 40
        targets = (prompt?.mustUse ?? []).filter(Self.isCheckable).map { ($0, Self.uses($0, in: text)) }
        looksEnglish = Self.isEnglish(text)
    }

    /// "although" can be found in text; "use the present perfect" cannot.
    static func isCheckable(_ target: String) -> Bool {
        !target.lowercased().hasPrefix("use ") && target.split(separator: " ").count <= 4
    }

    /// Matches inflected forms too: "manage to" finds "managed to", "follow up on" finds "followed up on".
    static func uses(_ target: String, in text: String) -> Bool {
        let parts = target.lowercased().split(separator: " ").map { word -> String in
            var stem = String(word)
            if stem.count >= 4, stem.hasSuffix("e") { stem.removeLast() }
            let escaped = NSRegularExpression.escapedPattern(for: stem)
            return stem.count >= 3 ? escaped + "\\w*" : escaped
        }
        let pattern = "\\b" + parts.joined(separator: "\\s+") + "\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isEnglish(_ text: String) -> Bool {
        guard text.split(whereSeparator: \.isWhitespace).count >= 3 else { return true }
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.english, .spanish]
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
        return (hypotheses[.spanish] ?? 0) < 0.6
    }

    var canSubmit: Bool { words >= Self.minimumWords && looksEnglish }

    var targetsUsed: Int { targets.count(where: \.1) }

    /// Length toward the goal (60 %) and target words used (40 %), never below the XP floor.
    var quality: Double {
        let length = min(1, Double(words) / Double(max(goal, 1)))
        let use = targets.isEmpty ? length : Double(targetsUsed) / Double(targets.count)
        return max(XPRules.minimumQuality, 0.6 * length + 0.4 * use)
    }

    static func == (a: WriteCheck, b: WriteCheck) -> Bool {
        a.words == b.words && a.goal == b.goal && a.looksEnglish == b.looksEnglish
            && a.targets.map(\.0) == b.targets.map(\.0) && a.targets.map(\.1) == b.targets.map(\.1)
    }
}
