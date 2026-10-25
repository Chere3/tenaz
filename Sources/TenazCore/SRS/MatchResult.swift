import Foundation

/// How a typed answer compares with the target.
public enum MatchResult: Equatable, Sendable {
    /// Same as the target after normalization.
    case exact
    /// Same as an accepted variant.
    case accepted
    /// One letter off in a word of 6+ letters.
    case nearMiss
    case wrong
}
