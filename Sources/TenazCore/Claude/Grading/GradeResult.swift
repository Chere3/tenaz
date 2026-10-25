/// The structured output of one grading call (schema in `GradingRubric.schema(for:)`).
public struct GradeResult: Codable, Hashable, Sendable {
    public var criteria: [GradeCriterion]
    public var errors: [GradeError]
    public var feedbackLine: String

    enum CodingKeys: String, CodingKey {
        case criteria, errors
        case feedbackLine = "feedback_line"
    }

    public func score(_ criterion: String) -> Int? { criteria.first { $0.name == criterion }?.score }
}
