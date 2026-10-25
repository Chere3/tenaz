import Foundation

/// Unlock rules for a note's cards (PLAN F3, ruling 7): the budget counts notes, not cards.
/// A note starts with one primary card; siblings unlock as the note's memory grows.
public enum CardUnlock {
    /// C/K/R/L siblings unlock when the primary card reaches this stability (days).
    public static let siblingStabilityDays = 3.0
    /// P unlocks when the note's C or L card reaches this stability (days).
    public static let productionStabilityDays = 7.0

    /// The card that introduces a note: L for chunks, C for error patterns, R for single words.
    public static func primaryType(for kind: NoteKind) -> CardType {
        switch kind {
        case .chunk: .recall
        case .pattern: .cloze
        case .word, .falseFriend: .recognition
        }
    }

    /// `noteCards` are all cards of the card's note (the card itself included).
    public static func availability(of card: CardRecord, kind: NoteKind, noteCards: [CardRecord]) -> CardAvailability {
        guard card.state == .new else { return .sibling }
        let preferred = primaryType(for: kind)
        let primary = noteCards.first { $0.type == preferred }
            ?? noteCards.filter { $0.type != .production }.min { order($0.type) < order($1.type) }
        if card.type == .production {
            let best = noteCards.filter { $0.type == .cloze || $0.type == .recall }.compactMap(\.stability).max() ?? 0
            return best >= productionStabilityDays ? .sibling : .locked
        }
        guard let primary, primary.id != card.id else { return .introducesNote }
        return (primary.stability ?? 0) >= siblingStabilityDays ? .sibling : .locked
    }

    private static func order(_ t: CardType) -> Int { CardType.allCases.firstIndex(of: t) ?? 9 }
}
