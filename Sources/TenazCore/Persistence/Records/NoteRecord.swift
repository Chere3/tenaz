import Foundation
import GRDB

/// A word or chunk (`note` table). Its prompt text lives in the bundled `VocabEntry` named by `sourceRef`.
public struct NoteRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "note"

    public var id: String
    public var kind: NoteKind
    public var display: String
    public var lemma: String
    public var glossEs: String
    public var exampleEn: String
    public var exampleEs: String
    public var cefr: String
    public var freqRank: Int?
    public var tags: [String]
    public var mustKnow: Bool
    public var source: String
    public var sourceRef: String
    public var suspended: Bool

    public init(
        id: String, kind: NoteKind, display: String, lemma: String, glossEs: String, exampleEn: String,
        exampleEs: String, cefr: String, freqRank: Int? = nil, tags: [String], mustKnow: Bool,
        source: String, sourceRef: String, suspended: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.display = display
        self.lemma = lemma
        self.glossEs = glossEs
        self.exampleEn = exampleEn
        self.exampleEs = exampleEs
        self.cefr = cefr
        self.freqRank = freqRank
        self.tags = tags
        self.mustKnow = mustKnow
        self.source = source
        self.sourceRef = sourceRef
        self.suspended = suspended
    }

    /// The topic used to interleave a session (first tag).
    public var topic: String { tags.first ?? kind.rawValue }
}
