import Foundation
import NaturalLanguage

/// The gate's local checks (PLAN F2): word count, English (`NLLanguageRecognizer` ≥ 0.8), the target
/// chunk present (lemma-tolerant: "followed up" counts for "follow up"), and a type-token ratio floor.
/// Paste is impossible in the field itself; nothing here needs the network or Claude.
public enum GateChecker {
    public static func check(_ text: String, chunk: String?, requirement: GateRequirement = .standard) -> GateCheckResult {
        let tokens = words(in: text)
        guard !tokens.isEmpty else { return .empty(requirement, chunk: chunk) }
        let confidence = englishConfidence(text)
        let distinct = Set(tokens.map { $0.lowercased() }).count
        let ttr = Double(distinct) / Double(tokens.count)
        return GateCheckResult(
            words: tokens.count, minWords: requirement.minWords, targetWords: requirement.targetWords,
            englishConfidence: confidence, englishOK: confidence >= requirement.minEnglishConfidence,
            chunk: chunk, chunkPresent: chunk.map { contains(text, chunk: $0) } ?? true,
            typeTokenRatio: ttr, varietyOK: ttr >= requirement.minTypeTokenRatio)
    }

    public static func words(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
            .filter { $0.contains(where: \.isLetter) }
    }

    public static func englishConfidence(_ text: String) -> Double {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.languageHypotheses(withMaximum: 3)[.english] ?? 0
    }

    /// True when the chunk's words appear in order, next to each other, comparing lemmas and crude
    /// stems so inflected forms count. Placeholders like "somebody" or "sth" in a chunk match any word.
    public static func contains(_ text: String, chunk: String) -> Bool {
        let wanted = forms(chunk)
        let have = forms(text)
        guard !wanted.isEmpty, have.count >= wanted.count else { return false }
        for start in 0...(have.count - wanted.count) {
            let ok = wanted.indices.allSatisfy { i in
                let w = wanted[i]
                return placeholders.contains(w.word) || !w.keys.isDisjoint(with: have[start + i].keys)
            }
            if ok { return true }
        }
        return false
    }

    private static let placeholders: Set<String> = ["somebody", "someone", "something", "sb", "sth", "smb"]

    private struct Form { var word: String; var keys: Set<String> }

    private static func forms(_ text: String) -> [Form] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var out: [Form] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                             options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let word = text[range].lowercased()
            guard word.contains(where: \.isLetter) else { return true }
            var keys: Set<String> = [word, stem(word)]
            if let lemma = tag?.rawValue.lowercased() { keys.insert(lemma); keys.insert(stem(lemma)) }
            out.append(Form(word: word, keys: keys))
            return true
        }
        return out
    }

    /// A crude English stem, a fallback when the lemma tagger has no answer.
    static func stem(_ word: String) -> String {
        for suffix in ["ing", "ied", "ies", "ed", "es", "s"] where word.count > suffix.count + 2 && word.hasSuffix(suffix) {
            return String(word.dropLast(suffix.count))
        }
        return word
    }
}
