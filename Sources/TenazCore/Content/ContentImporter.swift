import Foundation
import GRDB

/// Turns bundled `VocabEntry`s into notes and cards (PLAN F3). Idempotent by id: rows that already
/// exist are left alone, so it runs on every launch and only adds what is new.
public enum ContentImporter {
    /// Tags that make a note must-know (higher desired retention).
    public static let mustKnowTags: Set<String> = ["meetings", "workplace", "error-pattern", "false-friend"]
    public static let mustKnowRetention = 0.93
    public static let defaultRetention = 0.90

    public static func kind(for entry: VocabEntry) -> NoteKind {
        if entry.tags.contains("error-pattern") { return .pattern }
        if entry.tags.contains("false-friend") { return .falseFriend }
        return entry.headword.contains(" ") ? .chunk : .word
    }

    public static func note(for entry: VocabEntry) -> NoteRecord {
        NoteRecord(
            id: entry.id, kind: kind(for: entry), display: entry.headword, lemma: entry.headword.lowercased(),
            glossEs: entry.es, exampleEn: entry.example, exampleEs: entry.exampleEs, cefr: entry.cefr,
            tags: entry.tags, mustKnow: !mustKnowTags.isDisjoint(with: entry.tags), source: "tenaz", sourceRef: entry.id
        )
    }

    public static func cards(for entry: VocabEntry, now: Date) -> [CardRecord] {
        let note = note(for: entry)
        let retention = note.mustKnow ? mustKnowRetention : defaultRetention
        return CardPrompt.importTypes(for: entry, kind: note.kind).map {
            CardRecord(noteId: note.id, type: $0, desiredRetention: retention, now: now)
        }
    }

    /// Inserts the notes and cards that do not exist yet, in one transaction.
    @discardableResult
    public static func importVocab(_ entries: [VocabEntry], into database: TenazDatabase, now: Date) throws -> ImportReport {
        try database.writer.write { db in
            var report = ImportReport()
            for entry in entries {
                try note(for: entry).insert(db, onConflict: .ignore)
                report.notesAdded += db.changesCount
                for card in cards(for: entry, now: now) {
                    try card.insert(db, onConflict: .ignore)
                    report.cardsAdded += db.changesCount
                }
            }
            return report
        }
    }
}
