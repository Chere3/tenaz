/// The four exam types (PLAN F5).
public enum ExamKind: String, Codable, CaseIterable, Sendable {
    case placement, daily, weekly, monthly

    /// How strongly an attempt moves the skill posteriors: the Daily Check is low-stakes evidence.
    public var evidenceWeight: Double { self == .daily ? 0.5 : 1.0 }

    /// Claude grading runs per writing/speaking task; monthly mocks take the median of three.
    public var gradingRuns: Int { self == .monthly ? 3 : 1 }
}
