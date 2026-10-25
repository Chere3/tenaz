import Foundation

/// The overall band: the average of the four section bands (reading, listening, writing,
/// speaking) rounded to the nearest 0.5, as ETS does for the 2026 TOEFL overall score. Exact ties
/// (x.25 / x.75) go DOWN, so the overall never rounds up past the evidence (PLAN §2 row 6, F7).
/// Section bands themselves are floored from theta.
public struct OverallBand: Hashable, Sendable {
    public var band: Double
    public var low: Double
    public var high: Double
    /// Mean of the four section thetas and its SD (sections treated as independent); used by promotion.
    public var thetaMean: Double
    public var sd: Double

    public static func floorToHalf(_ value: Double) -> Double { (value * 2 + 1e-9).rounded(.down) / 2 }

    public static func average(_ bands: [Double]) -> Double {
        guard !bands.isEmpty else { return 0 }
        let mean = bands.reduce(0, +) / Double(bands.count)
        return (mean * 2 - 1e-9).rounded(.toNearestOrAwayFromZero) / 2
    }

    public init(estimates: [ExamSkill: AbilityEstimator]) {
        let sections = ExamSkill.sections.map { estimates[$0] ?? AbilityEstimator() }
        band = Self.average(sections.map(\.band))
        low = Self.average(sections.map(\.bandRange.lowerBound))
        high = Self.average(sections.map(\.bandRange.upperBound))
        thetaMean = sections.map(\.mean).reduce(0, +) / Double(sections.count)
        sd = sqrt(sections.map { $0.sd * $0.sd }.reduce(0, +)) / Double(sections.count)
    }
}
