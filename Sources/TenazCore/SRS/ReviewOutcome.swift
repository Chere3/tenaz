import Foundation

/// Everything one answer changed. `ReviewStore.record` persists it.
public struct ReviewOutcome: Equatable, Sendable {
    public var before: CardRecord
    public var after: CardRecord
    public var rating: Rating
    /// Typed answers only: how the text compared with the target (for feedback).
    public var match: MatchResult?
    public var log: ReviewLogRecord
    public var event: ReviewEvent
    /// When the card comes back in this session (learning steps), or nil.
    public var comesBackAt: Date?
    /// Learning day (`yyyymmdd`) through which the note's other cards are buried.
    public var buryDay: Int
}
