/// Which rubric a free response is graded with.
public enum GradeKind: String, Codable, CaseIterable, Sendable {
    case writing, speaking
}
