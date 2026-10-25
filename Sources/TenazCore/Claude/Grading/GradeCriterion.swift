/// One rubric criterion as Claude scored it.
public struct GradeCriterion: Codable, Hashable, Sendable {
    public var name: String
    /// 0-5.
    public var score: Int
    public var evidenceQuotes: [String]
    public var cefr: String

    enum CodingKeys: String, CodingKey {
        case name, score, cefr
        case evidenceQuotes = "evidence_quotes"
    }
}
