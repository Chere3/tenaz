/// One language error Claude found; feeds `error_ledger`.
public struct GradeError: Codable, Hashable, Sendable {
    public var span: String
    public var category: String
    public var correction: String
    public var ruleShort: String

    enum CodingKeys: String, CodingKey {
        case span, category, correction
        case ruleShort = "rule_short"
    }
}
