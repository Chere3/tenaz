import Foundation

/// What was already answered in the current learning day.
public struct DailyCounts: Equatable, Sendable {
    /// Cards answered for the first time today.
    public var newIntroduced: Int
    /// All answers today (new included).
    public var answered: Int

    public init(newIntroduced: Int = 0, answered: Int = 0) {
        self.newIntroduced = newIntroduced
        self.answered = answered
    }
}
