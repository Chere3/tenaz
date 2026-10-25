/// A written or spoken output (sentence, paragraph, gate text, spoken summary).
public struct Production: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case written, spoken, spokenSummary }

    /// Anti-farming key (prompt or card id).
    public var refId: String
    /// 0...1 from Claude's rubric, or from the local length + variety floors when Claude is down.
    public var quality: Double
    public var words: Int
    public var kind: Kind
    /// Only scanned locally for the hidden "my fly" achievement; never stored.
    public var text: String?

    public init(refId: String, quality: Double, words: Int, kind: Kind = .written, text: String? = nil) {
        self.refId = refId
        self.quality = quality
        self.words = words
        self.kind = kind
        self.text = text
    }

    public static let paragraphWords = 40
}
