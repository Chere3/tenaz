import Foundation

/// A finished Weekly Mock as promotion sees it.
public struct WeeklyEvidence: Hashable, Sendable {
    public var attemptId: String
    public var endedAt: Date
    public var overallMean: Double

    public init(attemptId: String, endedAt: Date, overallMean: Double) {
        self.attemptId = attemptId
        self.endedAt = endedAt
        self.overallMean = overallMean
    }
}
