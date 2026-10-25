import Foundation

/// What one card shows and what counts as right, built from the bundled `VocabEntry`.
public struct CardPrompt: Equatable, Sendable {
    public var type: CardType
    /// Main line (English chunk, cloze sentence, Spanish cue, ...).
    public var text: String
    /// Secondary line, or nil.
    public var hint: String?
    /// Recognition only: four options and the right one.
    public var options: [String]
    public var correctOption: Int?
    /// Typed cards: the target answer and other answers graded as fully right.
    public var expected: String?
    public var accepted: [String]

    /// The card types a note gets at import: R/C/L (error patterns: C only), K when a collocation has a
    /// slot, and P (locked by `CardUnlock` until C or L is stable). S waits for speech (M12).
    public static func importTypes(for entry: VocabEntry, kind: NoteKind) -> [CardType] {
        var types: [CardType] = kind == .pattern ? [.cloze] : [.recognition, .cloze, .recall]
        if collocationSlot(entry) != nil { types.append(.collocation) }
        types.append(.production)
        return types
    }

    /// `glossPool` supplies the wrong Spanish options for recognition cards.
    public static func make(entry: VocabEntry, type: CardType, glossPool: [String]) -> CardPrompt {
        let seed = stableHash(entry.id)
        switch type {
        case .recognition:
            var wrong: [String] = []
            let pool = glossPool.filter { $0.lowercased() != entry.es.lowercased() }
            let start = Int(seed % UInt64(max(pool.count, 1)))
            for j in 0..<pool.count where wrong.count < 3 {
                let g = pool[(start + j) % pool.count]
                if !wrong.contains(g) { wrong.append(g) }
            }
            let at = Int(seed % UInt64(wrong.count + 1))
            var options = wrong
            options.insert(entry.es, at: at)
            return CardPrompt(type: type, text: entry.headword, hint: entry.example, options: options, correctOption: at, expected: nil, accepted: [])
        case .cloze:
            return typed(type, entry.cloze, hint: entry.es, expected: entry.answer, also: [])
        case .recall:
            return typed(type, entry.es, hint: entry.definition, expected: entry.headword, also: [entry.answer])
        case .collocation:
            let slot = collocationSlot(entry) ?? (entry.cloze, entry.answer)
            return typed(type, slot.prompt, hint: entry.es, expected: slot.answer, also: [])
        case .production:
            return CardPrompt(type: type, text: "Write a sentence using \"\(entry.headword)\".", hint: entry.definition, options: [], correctOption: nil, expected: nil, accepted: [])
        case .spelling:
            return typed(type, entry.headword, hint: entry.es, expected: entry.headword, also: [])
        }
    }

    /// The first collocation that contains the answer (or headword) plus other words, with that part blanked.
    public static func collocationSlot(_ entry: VocabEntry) -> (prompt: String, answer: String)? {
        for phrase in entry.collocations {
            for target in [entry.answer, entry.headword] where !target.isEmpty {
                guard phrase.lowercased() != target.lowercased(), let r = wholeWordRange(of: target, in: phrase) else { continue }
                return (phrase.replacingCharacters(in: r, with: "____"), String(phrase[r]))
            }
        }
        return nil
    }

    private static func typed(_ type: CardType, _ text: String, hint: String?, expected: String, also: [String]) -> CardPrompt {
        let accepted = also.filter { $0.lowercased() != expected.lowercased() }
        return CardPrompt(type: type, text: text, hint: hint, options: [], correctOption: nil, expected: expected, accepted: accepted)
    }

    private static func wholeWordRange(of target: String, in phrase: String) -> Range<String.Index>? {
        var search = phrase.startIndex..<phrase.endIndex
        while let r = phrase.range(of: target, options: .caseInsensitive, range: search) {
            let beforeOK = r.lowerBound == phrase.startIndex || !phrase[phrase.index(before: r.lowerBound)].isLetter
            let afterOK = r.upperBound == phrase.endIndex || !phrase[r.upperBound].isLetter
            if beforeOK, afterOK { return r }
            search = r.upperBound..<phrase.endIndex
        }
        return nil
    }

    /// FNV-1a, so option order is the same on every launch (`hashValue` is seeded per process).
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01B3 }
        return h
    }
}
