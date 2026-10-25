import Foundation

/// Looks up the bundled entry behind each note and builds its card prompts.
public struct PromptBook: Sendable {
    private let entries: [String: VocabEntry]
    /// Spanish glosses grouped by part of speech, the wrong options for recognition cards.
    private let glossesByPos: [String: [String]]
    private let allGlosses: [String]

    public init(vocab: [VocabEntry]) {
        var entries: [String: VocabEntry] = [:]
        var glosses: [String: [String]] = [:]
        for e in vocab where entries[e.id] == nil {
            entries[e.id] = e
            glosses[e.pos, default: []].append(e.es)
        }
        self.entries = entries
        glossesByPos = glosses
        allGlosses = vocab.map(\.es)
    }

    public func entry(for note: NoteRecord) -> VocabEntry? { entries[note.sourceRef] }

    /// nil when the note's entry is no longer bundled.
    public func prompt(for card: CardRecord, note: NoteRecord) -> CardPrompt? {
        guard let entry = entry(for: note) else { return nil }
        // Rare parts of speech borrow from every gloss so there are always 3 wrong options.
        let samePos = Set(glossesByPos[entry.pos] ?? []).subtracting([entry.es])
        let pool = samePos.count >= 3 ? glossesByPos[entry.pos] ?? [] : (glossesByPos[entry.pos] ?? []) + allGlosses
        return CardPrompt.make(entry: entry, type: card.type, glossPool: pool)
    }
}
