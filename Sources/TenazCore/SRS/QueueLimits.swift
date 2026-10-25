import Foundation

/// Load control for "today's set" (PLAN F3).
public struct QueueLimits: Equatable, Sendable {
    public var newPerDay = 5
    /// At most one new card per this many reviews (interleaving; spare new cards go last).
    public var reviewsPerNew = 4
    /// Answers per learning day, all surfaces together.
    public var dailyCap = 120
    /// No new cards while more than this many are due.
    public var suspendNewAboveDue = 80
    /// Never more than this many cards of one type or topic in a row (when there is a choice).
    public var maxSameInARow = 3

    public init() {}

    public static let standard = QueueLimits()
}
