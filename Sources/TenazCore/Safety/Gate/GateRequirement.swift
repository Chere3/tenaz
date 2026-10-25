/// What the unlock gate asks for (PLAN ruling 5): 2-3 sentences, 25-40 words, one target chunk,
/// in English, with some variety.
public struct GateRequirement: Codable, Equatable, Sendable {
    public var minWords: Int
    public var targetWords: Int
    public var minEnglishConfidence: Double
    public var minTypeTokenRatio: Double

    public init(minWords: Int = 25, targetWords: Int = 40, minEnglishConfidence: Double = 0.8, minTypeTokenRatio: Double = 0.5) {
        self.minWords = minWords
        self.targetWords = targetWords
        self.minEnglishConfidence = minEnglishConfidence
        self.minTypeTokenRatio = minTypeTokenRatio
    }

    public static let standard = GateRequirement()
}
