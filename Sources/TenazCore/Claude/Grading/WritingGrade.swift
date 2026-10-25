/// `writing_entry.gradeJSON`: every finished run, then the medians once all runs are in.
public struct WritingGrade: Codable, Hashable, Sendable {
    public var runs: [GradeResult]
    public var medians: [String: Double]?
    /// Mean of the criterion medians, 0-5.
    public var score: Double?
    public var lowConfidence: Bool?
}
