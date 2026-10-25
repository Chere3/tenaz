import Foundation

/// Finds the deck entry for a word in a text, so the reader can show its gloss when tapped.
/// Only single-word headwords; when several entries share a form, the preferred ids win, then the
/// lowest id (stable).
public struct GlossIndex: Sendable {
    private let byForm: [String: [VocabEntry]]

    public init(vocab: [VocabEntry]) {
        var map: [String: [VocabEntry]] = [:]
        for entry in vocab where !entry.headword.contains(" ") {
            for form in WordForms.forms(of: entry.headword) { map[form, default: []].append(entry) }
        }
        byForm = map.mapValues { $0.sorted { $0.id < $1.id } }
    }

    public func entry(for token: String, preferring preferred: Set<String> = []) -> VocabEntry? {
        guard let entries = byForm[token.lowercased()] else { return nil }
        return entries.first { preferred.contains($0.id) } ?? entries.first
    }
}
