import Foundation

/// A finished Monthly Full Mock as promotion sees it.
public struct MonthlyEvidence: Hashable, Sendable {
    public var attemptId: String
    public var endedAt: Date
    /// Overall theta (mean of the four section thetas) and its SD.
    public var overallMean: Double
    public var overallSD: Double
    public var sectionBands: [ExamSkill: Double]
    /// CLEAN, or WARNING confirmed by the learner.
    public var verified: Bool

    public init(attemptId: String, endedAt: Date, overallMean: Double, overallSD: Double,
                sectionBands: [ExamSkill: Double], verified: Bool) {
        self.attemptId = attemptId
        self.endedAt = endedAt
        self.overallMean = overallMean
        self.overallSD = overallSD
        self.sectionBands = sectionBands
        self.verified = verified
    }
}
