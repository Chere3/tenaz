import Foundation
import GRDB

/// One scheduled card (`card` table). Times are Unix milliseconds; `buriedUntilDay` is a `yyyymmdd`
/// learning day through which the card is hidden (sibling burying).
public struct CardRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "card"

    public var id: String
    public var noteId: String
    public var type: CardType
    public var state: CardStatus
    public var step: Int?
    public var due: Int64
    public var stability: Double?
    public var difficulty: Double?
    public var reps: Int
    public var lapses: Int
    public var lastReview: Int64?
    public var desiredRetention: Double
    public var leech: Bool
    public var buriedUntilDay: Int?

    /// Lapses at which a card is flagged as a leech (PLAN F3).
    public static let leechLapses = 6

    public static func id(noteId: String, type: CardType) -> String { "\(noteId):\(type.rawValue)" }

    /// A never-reviewed card, due immediately.
    public init(noteId: String, type: CardType, desiredRetention: Double, now: Date) {
        id = Self.id(noteId: noteId, type: type)
        self.noteId = noteId
        self.type = type
        state = .new
        step = 0
        due = now.unixMilliseconds
        reps = 0
        lapses = 0
        self.desiredRetention = desiredRetention
        leech = false
    }

    /// The scheduler's view of this card.
    public var memory: MemoryState {
        let cardState: TenazCore.CardState = switch state {
        case .new, .learning: .learning
        case .review: .review
        case .relearning: .relearning
        }
        return MemoryState(
            stability: stability, difficulty: difficulty, state: cardState,
            due: Date(unixMilliseconds: due), lastReview: lastReview.map(Date.init(unixMilliseconds:)),
            reps: reps, lapses: lapses, step: state == .review ? nil : (step ?? 0)
        )
    }

    /// Copies a scheduler result back into the record.
    public mutating func apply(_ m: MemoryState) {
        state = CardStatus(m)
        step = m.step
        due = (m.due ?? Date()).unixMilliseconds
        stability = m.stability
        difficulty = m.difficulty
        reps = m.reps
        lapses = m.lapses
        lastReview = m.lastReview?.unixMilliseconds
        if lapses >= Self.leechLapses { leech = true }
    }

    public var dueDate: Date { Date(unixMilliseconds: due) }
}
