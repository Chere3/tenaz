import Foundation

/// Simple English inflections, enough to find a deck word inside a text ("predicts", "refactoring",
/// "allocated", "studies"). Not a lemmatizer; the coverage service (M13) will use NLTagger.
public enum WordForms {
    public static func forms(of headword: String) -> Set<String> {
        let h = headword.lowercased()
        var f: Set<String> = [h, h + "s", h + "es", h + "ed", h + "d", h + "ing"]
        if h.hasSuffix("e") { f.insert(String(h.dropLast()) + "ing") }
        if h.hasSuffix("y") { f.formUnion([String(h.dropLast()) + "ies", String(h.dropLast()) + "ied"]) }
        let chars = Array(h)
        if chars.count >= 3 {
            let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
            let (a, b, c) = (chars[chars.count - 3], chars[chars.count - 2], chars[chars.count - 1])
            if !vowels.contains(a), vowels.contains(b), !vowels.contains(c), !"wyx".contains(c) {
                f.formUnion([h + String(c) + "ed", h + String(c) + "ing"])
            }
        }
        return f
    }

    /// Lowercased word tokens of a text (letters, inner hyphens and apostrophes kept).
    public static func tokens(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in text.lowercased() {
            if ch.isLetter || ((ch == "-" || ch == "'" || ch == "’") && !current.isEmpty) {
                current.append(ch == "’" ? "'" : ch)
            } else if !current.isEmpty {
                out.append(current.trimmingCharacters(in: CharacterSet(charactersIn: "-'")))
                current = ""
            }
        }
        if !current.isEmpty { out.append(current.trimmingCharacters(in: CharacterSet(charactersIn: "-'"))) }
        return out.filter { !$0.isEmpty }
    }

    public static func text(_ text: String, mentions headword: String) -> Bool {
        !forms(of: headword).isDisjoint(with: tokens(text))
    }
}
