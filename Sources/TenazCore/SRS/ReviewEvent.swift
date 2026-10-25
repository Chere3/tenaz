import Foundation

/// Emitted after every answer so other areas (XP, quests, mascot) can react without the session
/// knowing about them.
public struct ReviewEvent: Equatable, Sendable {
    public var cardId: String
    public var noteId: String
    public var cardType: CardType
    public var rating: Rating
    /// The answer was right (anything but Again).
    public var correct: Bool
    /// First time this card was ever answered.
    public var wasNew: Bool
    public var surface: ReviewSurface
    public var durationMs: Int
    public var at: Date
}
