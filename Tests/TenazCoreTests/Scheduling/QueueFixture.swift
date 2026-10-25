import Foundation
@testable import TenazCore

/// Small builders for queue and session tests.
enum QueueFixture {
    static let now = Date(timeIntervalSince1970: 1_792_000_000)
    static var day: Int { DayBoundary.day(for: now) }

    static func note(_ id: String, kind: NoteKind = .word, tag: String = "core", mustKnow: Bool = false) -> NoteRecord {
        NoteRecord(
            id: id, kind: kind, display: id, lemma: id, glossEs: "es-\(id)", exampleEn: "", exampleEs: "",
            cefr: "B2", tags: [tag], mustKnow: mustKnow, source: "test", sourceRef: id
        )
    }

    static func newCard(_ noteId: String, _ type: CardType) -> CardRecord {
        CardRecord(noteId: noteId, type: type, desiredRetention: 0.9, now: now)
    }

    /// A card in review, due `dueOffset` seconds from `now` (negative = overdue).
    static func reviewCard(_ noteId: String, _ type: CardType, stability: Double = 5, dueOffset: TimeInterval = -60) -> CardRecord {
        var c = newCard(noteId, type)
        c.state = .review
        c.step = nil
        c.stability = stability
        c.difficulty = 5
        c.reps = 3
        c.lastReview = now.addingTimeInterval(-86400 * stability).unixMilliseconds
        c.due = now.addingTimeInterval(dueOffset).unixMilliseconds
        return c
    }

    static func notes(_ list: [NoteRecord]) -> [String: NoteRecord] {
        Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }
}
