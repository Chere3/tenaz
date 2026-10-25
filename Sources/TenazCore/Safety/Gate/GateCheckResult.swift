/// The four local checks, computed on every keystroke (no network, instant).
public struct GateCheckResult: Equatable, Sendable {
    public var words: Int
    public var minWords: Int
    public var targetWords: Int
    /// `NLLanguageRecognizer` confidence that the text is English (0...1).
    public var englishConfidence: Double
    public var englishOK: Bool
    public var chunk: String?
    public var chunkPresent: Bool
    /// Distinct words / words.
    public var typeTokenRatio: Double
    public var varietyOK: Bool

    public var lengthOK: Bool { words >= minWords }
    public var passes: Bool { lengthOK && englishOK && chunkPresent && varietyOK }
    /// 0...1 toward the target length, for the word meter.
    public var progress: Double { min(1, Double(words) / Double(max(1, targetWords))) }

    public static func empty(_ requirement: GateRequirement, chunk: String?) -> GateCheckResult {
        GateCheckResult(words: 0, minWords: requirement.minWords, targetWords: requirement.targetWords, englishConfidence: 0,
                        englishOK: false, chunk: chunk, chunkPresent: chunk == nil, typeTokenRatio: 0, varietyOK: false)
    }
}
