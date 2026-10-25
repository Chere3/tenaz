import Foundation

/// The `card.state` column. `new` is a learning card that has never been reviewed.
public enum CardStatus: String, Codable, Sendable {
    case new, learning, review, relearning

    public init(_ memory: MemoryState) {
        if memory.isNew { self = .new; return }
        switch memory.state {
        case .learning: self = .learning
        case .review: self = .review
        case .relearning: self = .relearning
        }
    }
}
