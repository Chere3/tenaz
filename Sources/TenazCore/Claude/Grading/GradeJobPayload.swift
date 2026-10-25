/// `claude_job.payload` for kind "grade": which writing_entry to grade and how.
public struct GradeJobPayload: Codable, Hashable, Sendable {
    public var entryId: Int64
    public var skill: ExamSkill
    public var kind: GradeKind
    /// 3 for monthly mocks (median), else 1.
    public var runs: Int
    /// Evidence weight for the skill posterior (daily 0.5, others 1.0).
    public var weight: Double
    public var typed: Bool
}
