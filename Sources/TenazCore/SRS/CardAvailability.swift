import Foundation

/// Whether a never-reviewed card may enter today's set, and what it costs (PLAN F3).
public enum CardAvailability: Equatable, Sendable {
    /// Not yet: its unlock rule is not met.
    case locked
    /// The note's first card: showing it introduces the note and spends 1 from the daily new-note budget.
    case introducesNote
    /// A sibling of an introduced note: free of the note budget.
    case sibling
}
